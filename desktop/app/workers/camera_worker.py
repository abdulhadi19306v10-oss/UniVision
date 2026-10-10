import cv2
import time
import numpy as np
from typing import Dict, Optional
from PySide6.QtCore import QThread, Signal

from ..events.event_bus import desktop_event_bus
from ..recognition.detector import YuNetDetector
from ..recognition.embedder import SFaceEmbedder
from ..recognition.matcher import CosineMatcher
from ..recognition.tracker import ConsecutiveFrameTracker
from ..recognition.liveness import LivenessDetector
from ..storage.local_db import LocalStorage

class CameraWorker(QThread):
    """
    Dedicated background worker thread for camera capture and ONNX neural network inference.
    Completely offloads video decoding, face detection, feature embedding, and vector matching
    from the PySide6 GUI thread, ensuring 60 FPS responsive UI.
    """
    def __init__(self, storage: LocalStorage, camera_index: int = 0):
        super().__init__()
        self.storage = storage
        self.camera_index = camera_index
        self.running = False

        # AI Pipeline Components
        self.detector = YuNetDetector()
        self.embedder = SFaceEmbedder()
        self.matcher = CosineMatcher(threshold=0.363)
        self.tracker = ConsecutiveFrameTracker(required_consecutive_frames=3)
        self.liveness = LivenessDetector()

        # Cache of enrolled embeddings {student_id: np_array}
        self.enrolled_embeddings: Dict[int, np.ndarray] = {}
        self.reload_enrolled_embeddings()

        # Enrollment capture state
        self.is_enrolling = False
        self.enrollment_samples = []
        self.enrollment_target = {}

    def reload_enrolled_embeddings(self):
        self.enrolled_embeddings = self.storage.get_all_enrolled_embeddings()

    def start_enrollment(self, student_id: int, roll_no: str, full_name: str):
        self.enrollment_target = {"id": student_id, "roll_no": roll_no, "full_name": full_name}
        self.enrollment_samples = []
        self.is_enrolling = True

    def stop_worker(self):
        self.running = False
        self.wait(1000)

    def run(self):
        self.running = True
        cap = cv2.VideoCapture(self.camera_index)
        if not cap.isOpened():
            print(f"[CameraWorker] Error: Camera index {self.camera_index} could not be opened.")
            return

        fps_timer = time.time()
        frame_counter = 0
        fps = 0.0

        while self.running:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.03)
                continue

            frame_counter += 1
            now = time.time()
            if now - fps_timer >= 1.0:
                fps = frame_counter / (now - fps_timer)
                fps_timer = now
                frame_counter = 0

            display_frame = frame.copy()
            faces = self.detector.detect(frame)
            detected_summaries = []

            if self.is_enrolling:
                # Enrollment Mode: Gather 5 valid single-face samples
                if len(faces) == 1:
                    feat = self.embedder.extract_feature(frame, faces[0])
                    self.enrollment_samples.append(feat)
                    sample_count = len(self.enrollment_samples)
                    cv2.putText(display_frame, f"ENROLLING: {sample_count}/5", (20, 50),
                                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

                    if sample_count >= 5:
                        self.is_enrolling = False
                        avg_emb = self.embedder.average_embeddings(self.enrollment_samples)
                        self.storage.save_enrolled_student(
                            self.enrollment_target["id"],
                            self.enrollment_target["roll_no"],
                            self.enrollment_target["full_name"],
                            avg_emb
                        )
                        self.reload_enrolled_embeddings()
                        desktop_event_bus.sync_status_changed.emit(
                            f"Enrolled {self.enrollment_target['full_name']} ({self.enrollment_target['roll_no']})",
                            {"action": "ENROLLMENT_COMPLETED"}
                        )
            else:
                # Live Recognition Mode
                best_match_id = None
                for face in faces:
                    box = face[0:4].astype(np.int32)
                    x, y, fw, fh = box
                    feat = self.embedder.extract_feature(frame, face)

                    # Cosine vector match against locally enrolled embeddings
                    match_id, sim = self.matcher.find_best_match(feat, self.enrolled_embeddings)

                    color = (0, 0, 255) # Red default
                    label = "Unknown"

                    if match_id is not None:
                        details = self.storage.get_student_details(match_id)
                        name = details[1] if details else f"Student #{match_id}"
                        roll = details[0] if details else ""

                        # Evaluate consecutive frame confirmation tracker
                        best_match_id = match_id
                        confirmed_id, is_newly_marked = self.tracker.update(match_id)

                        if confirmed_id:
                            color = (0, 255, 0) # Green confirmed
                            label = f"{name} ({roll}) [{sim*100:.0f}%]"

                            # Publish domain event through EventBus
                            if is_newly_marked:
                                desktop_event_bus.attendance_confirmed.emit(confirmed_id, roll, name, sim)
                        else:
                            color = (0, 255, 255) # Yellow verifying
                            streak = self.tracker.streak_counts.get(match_id, 0)
                            label = f"Verifying {name} ({streak}/3)..."

                        detected_summaries.append({"id": match_id, "name": name, "roll": roll, "sim": sim})
                    else:
                        self.tracker.update(None)

                    # Render bounding box and label
                    cv2.rectangle(display_frame, (x, y), (x + fw, y + fh), color, 2)
                    cv2.putText(display_frame, label, (x, max(20, y - 8)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)

                if not faces:
                    self.tracker.update(None)

            # Publish processed frame to EventBus for UI presentation
            desktop_event_bus.frame_processed.emit(display_frame, detected_summaries, fps)

            # Target ~30 FPS loop rate
            time.sleep(0.01)

        cap.release()
