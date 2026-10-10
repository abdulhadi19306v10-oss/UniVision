import logging
from typing import Dict, Set
from fastapi import WebSocket
from ..event_bus import event_bus

logger = logging.getLogger("backend.handlers.notification")

class WebSocketConnectionManager:
    """
    Tracks active WebSocket connections to push real-time attendance events
    directly to student mobile apps or live dashboards.
    """
    def __init__(self):
        # Maps student_id to set of active WebSockets
        self.student_sockets: Dict[int, Set[WebSocket]] = {}
        # Global broadcast sockets (e.g., live admin dashboard)
        self.broadcast_sockets: Set[WebSocket] = set()

    async def connect_student(self, student_id: int, websocket: WebSocket):
        await websocket.accept()
        if student_id not in self.student_sockets:
            self.student_sockets[student_id] = set()
        self.student_sockets[student_id].add(websocket)
        logger.info(f"[NotificationManager] Student {student_id} connected over WebSocket.")

    def disconnect_student(self, student_id: int, websocket: WebSocket):
        if student_id in self.student_sockets:
            self.student_sockets[student_id].discard(websocket)
            if not self.student_sockets[student_id]:
                del self.student_sockets[student_id]

    async def connect_broadcast(self, websocket: WebSocket):
        await websocket.accept()
        self.broadcast_sockets.add(websocket)

    def disconnect_broadcast(self, websocket: WebSocket):
        self.broadcast_sockets.discard(websocket)

    async def notify_student(self, student_id: int, message: dict):
        if student_id in self.student_sockets:
            for ws in list(self.student_sockets[student_id]):
                try:
                    await ws.send_json(message)
                except Exception:
                    self.disconnect_student(student_id, ws)

    async def broadcast(self, message: dict):
        for ws in list(self.broadcast_sockets):
            try:
                await ws.send_json(message)
            except Exception:
                self.disconnect_broadcast(ws)

notification_manager = WebSocketConnectionManager()

async def on_attendance_marked_push(payload: dict):
    student_id = payload.get("student_id")
    course_name = payload.get("course_name", "your class")

    notification_payload = {
        "type": "ATTENDANCE_CONFIRMED",
        "title": "Attendance Marked",
        "body": f"You were marked PRESENT in {course_name}",
        "data": payload
    }

    if student_id:
        await notification_manager.notify_student(student_id, notification_payload)
    await notification_manager.broadcast(notification_payload)

event_bus.subscribe("AttendanceMarked", on_attendance_marked_push)
