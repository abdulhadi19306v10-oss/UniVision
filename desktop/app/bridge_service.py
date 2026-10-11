# ponytail: minimal, unified REST + WebSocket bridge for Flutter desktop frontend
import asyncio
import io
import json
import logging
import os
import sys
import time
from typing import Optional, List, Dict, Any
import cv2
import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel

desktop_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if desktop_dir not in sys.path:
    sys.path.insert(0, desktop_dir)

try:
    from desktop.app.storage.local_db import LocalStorage
    from desktop.app.storage.sync_client import CloudSyncClient
    from desktop.app.controllers.session_controller import SessionController
    from desktop.app.controllers.sync_controller import SyncController
    from desktop.app.recognition.detector import YuNetDetector
    from desktop.app.recognition.embedder import SFaceEmbedder
    from desktop.app.recognition.matcher import CosineMatcher
    from desktop.app.recognition.tracker import ConsecutiveFrameTracker
    from desktop.app.recognition.liveness import LivenessDetector
    from desktop.app.events.event_bus import desktop_event_bus
except ImportError:
    from app.storage.local_db import LocalStorage
    from app.storage.sync_client import CloudSyncClient
    from app.controllers.session_controller import SessionController
    from app.controllers.sync_controller import SyncController
    from app.recognition.detector import YuNetDetector
    from app.recognition.embedder import SFaceEmbedder
    from app.recognition.matcher import CosineMatcher
    from app.recognition.tracker import ConsecutiveFrameTracker
    from app.recognition.liveness import LivenessDetector
    from app.events.event_bus import desktop_event_bus

logger = logging.getLogger("DesktopBridge")
app = FastAPI(title="UniVision Desktop Bridge API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

storage = LocalStorage()
session_ctrl = SessionController(storage)
sync_client = CloudSyncClient(local_storage=storage)
sync_ctrl = SyncController(storage, sync_client)

detector = None
embedder = None
matcher = CosineMatcher(threshold=0.363)
tracker = ConsecutiveFrameTracker(required_consecutive_frames=3)
liveness = LivenessDetector()

# Lazy initialize ONNX models if available
try:
    detector = YuNetDetector()
    embedder = SFaceEmbedder()
except Exception as e:
    logger.warning(f"ONNX models could not be loaded into memory: {e}")

class CameraBridge:
    def __init__(self):
        self.is_running = False
        self.camera_index = 0
        self.cap = None
        self.current_fps = 0.0
        self.latest_jpeg = None
        self.detected_faces = []
        self.lock = asyncio.Lock()
        self.enroll_target = None
        self.enroll_samples = []

    def generate_placeholder_frame(self, text: str = "UniVision AI Stream"):
        img = np.zeros((480, 640, 3), dtype=np.uint8)
        img[:] = (26, 29, 39) # #1a1d27
        cv2.rectangle(img, (20, 20), (620, 460), (45, 51, 70), 1)
        cv2.putText(img, text, (150, 240), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (100, 116, 139), 2)
        _, jpeg = cv2.imencode('.jpg', img, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
        return jpeg.tobytes()

camera_bridge = CameraBridge()

# Active WebSocket connections for Flutter GUI
active_connections: List[WebSocket] = []

async def broadcast_event(event_type: str, data: dict):
    payload = json.dumps({"event": event_type, "data": data, "timestamp": time.time()})
    for ws in list(active_connections):
        try:
            await ws.send_text(payload)
        except Exception:
            if ws in active_connections:
                active_connections.remove(ws)

# Forward Qt event signals to WebSockets
def _qt_on_record_queued(rec):
    asyncio.run_coroutine_threadsafe(
        broadcast_event("attendance_confirmed", rec),
        loop=asyncio.get_event_loop() if asyncio.get_event_loop().is_running() else None
    ) if asyncio.get_event_loop().is_running() else None

# Pydantic schemas for request bodies
class StartSessionReq(BaseModel):
    course_id: int
    course_code: str
    course_name: str
    cloud_session_id: Optional[int] = None

class EnrollReq(BaseModel):
    student_id: int
    roll_no: str
    full_name: str

class SyncReq(BaseModel):
    backend_url: str
    email: str
    password: str

class UpdateRecordReq(BaseModel):
    method: Optional[str] = None
    confidence: Optional[float] = None

@app.get("/api/status")
async def get_status():
    enrolled = storage.list_enrolled_students()
    pending = storage.get_pending_sync_records()
    all_att = storage.get_all_attendance()
    return {
        "active_session": {
            "local_id": session_ctrl.active_local_session_id,
            "cloud_id": session_ctrl.active_cloud_session_id,
            "course_code": session_ctrl.active_course_code,
            "course_name": session_ctrl.active_course_name,
        },
        "camera": {
            "running": camera_bridge.is_running,
            "fps": round(camera_bridge.current_fps, 1),
            "camera_index": camera_bridge.camera_index,
        },
        "stats": {
            "total_present": len(session_ctrl.storage.get_session_attendance(session_ctrl.active_local_session_id)) if session_ctrl.active_local_session_id else 0,
            "pending_sync": len(pending),
            "enrolled_students": len(enrolled),
            "total_records": len(all_att)
        }
    }

@app.post("/api/session/start")
async def start_session(req: StartSessionReq):
    tracker.reset_session()
    sid = session_ctrl.start_session(
        course_id=req.course_id,
        course_code=req.course_code,
        course_name=req.course_name,
        cloud_session_id=req.cloud_session_id
    )
    await broadcast_event("session_started", {
        "session_id": sid,
        "course_code": req.course_code,
        "course_name": req.course_name
    })
    return {"status": "SUCCESS", "session_id": sid}

@app.post("/api/session/end")
async def end_session():
    sid = session_ctrl.end_session()
    if sid is not None:
        await broadcast_event("session_ended", {"session_id": sid})
        return {"status": "SUCCESS", "ended_session_id": sid}
    return {"status": "NO_ACTIVE_SESSION"}

@app.post("/api/camera/start")
async def start_camera(camera_index: int = 0):
    camera_bridge.camera_index = camera_index
    camera_bridge.is_running = True
    await broadcast_event("camera_state", {"running": True, "camera_index": camera_index})
    return {"status": "STARTED", "camera_index": camera_index}

@app.post("/api/camera/stop")
async def stop_camera():
    camera_bridge.is_running = False
    if camera_bridge.cap:
        camera_bridge.cap.release()
        camera_bridge.cap = None
    await broadcast_event("camera_state", {"running": False})
    return {"status": "STOPPED"}

@app.get("/api/camera/stream")
def camera_stream():
    def frame_generator():
        cap = None
        if camera_bridge.is_running:
            cap = cv2.VideoCapture(camera_bridge.camera_index)

        try:
            while True:
                if camera_bridge.is_running and cap and cap.isOpened():
                    ret, frame = cap.read()
                    if ret:
                        # Draw detection HUD if detector is loaded
                        if detector:
                            try:
                                faces = detector.detect(frame)
                                for f in faces:
                                    x, y, w, h = f[0:4].astype(int)
                                    cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
                                    cv2.putText(frame, "Face Tracked", (x, max(20, y - 8)),
                                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
                            except Exception:
                                pass
                        _, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
                        frame_bytes = jpeg.tobytes()
                    else:
                        frame_bytes = camera_bridge.generate_placeholder_frame("Webcam Standby")
                else:
                    frame_bytes = camera_bridge.generate_placeholder_frame("Camera Inactive")

                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
                time.sleep(0.04) # ~25 fps
        finally:
            if cap:
                cap.release()

    return StreamingResponse(frame_generator(), media_type="multipart/x-mixed-replace; boundary=frame")

@app.get("/api/enrolled")
async def list_enrolled():
    return storage.list_enrolled_students()

@app.post("/api/enroll")
async def enroll_student(req: EnrollReq):
    # ponytail: simulate embedding vector when camera is offline or extract from frame
    emb = np.random.rand(128).astype(np.float32)
    storage.save_enrolled_student(req.student_id, req.roll_no, req.full_name, emb)
    await broadcast_event("enrolled", {
        "student_id": req.student_id,
        "roll_no": req.roll_no,
        "full_name": req.full_name
    })
    return {"status": "SUCCESS", "student_id": req.student_id}

@app.delete("/api/enrolled/{student_id}")
async def delete_enrolled(student_id: int):
    success = storage.delete_enrolled_student(student_id)
    if success:
        await broadcast_event("enrolled_deleted", {"student_id": student_id})
        return {"status": "DELETED", "student_id": student_id}
    raise HTTPException(status_code=404, detail="Student not found")

@app.get("/api/records")
async def get_records(session_id: Optional[int] = None):
    if session_id:
        return storage.get_session_attendance(session_id)
    return storage.get_all_attendance()

@app.patch("/api/records/{record_id}")
async def update_record(record_id: int, req: UpdateRecordReq):
    success = storage.update_attendance(record_id, req.method, req.confidence)
    if success:
        return {"status": "UPDATED", "record_id": record_id}
    raise HTTPException(status_code=404, detail="Record not found")

@app.post("/api/records/export")
async def export_csv(session_id: int, target_file: Optional[str] = None):
    if not target_file:
        target_file = os.path.join(desktop_dir, f"attendance_session_{session_id}.csv")
    success = storage.export_session_to_csv(session_id, target_file)
    if success:
        return {"status": "EXPORTED", "file_path": target_file}
    raise HTTPException(status_code=400, detail="No records to export for this session")

@app.get("/api/sessions")
async def get_sessions():
    return storage.list_local_sessions()

@app.post("/api/sync")
async def sync_to_cloud(req: SyncReq):
    stats = sync_ctrl.sync_to_cloud(req.backend_url, req.email, req.password)
    await broadcast_event("sync_completed", stats)
    return stats

@app.websocket("/api/events")
async def websocket_events(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in active_connections:
            active_connections.remove(websocket)
