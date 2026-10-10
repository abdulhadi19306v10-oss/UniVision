import cv2
import time
import logging
import numpy as np
from typing import Dict, Optional, Set
from PySide6.QtCore import QThread, Signal

from ..events.event_bus import desktop_event_bus
from ..recognition.detector import YuNetDetector
from ..recognition.embedder import SFaceEmbedder
from ..recognition.matcher import CosineMatcher
from ..recognition.tracker import ConsecutiveFrameTracker
from ..recognition.liveness import LivenessDetector
from ..storage.local_db import LocalStorage

logger = logging.getLogger("CameraWorker")

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

        # Reset confirmation tracker when a new lecture session begins
        desktop_event_bus.session_started.connect(self.on_session_started)

    def on_session_started(self, local_id: int, course_code: str, course_name: str):
        logger.info(f"Resetting tracker state for new session #{local_id} ({course_code})")
        self.tracker.reset_session()

    def reload_enrolled_embeddings(self):
        self.enrolled_embeddings = self.storage.get_all_enrolled_embeddings()
        logger.info(f"Loaded {len(self.enrolled_embeddings)} enrolled embeddings from local database.")

    def start_enrollment(self, student_id: int, roll_no: str, full_name: str):
        self.enrollment_target = {"id": student_id, "roll_no": roll_no, "full_name": full_name}
        self.enrollment_samples = []
        self.is_enrolling = True
        logger.info(f"Initiated enrollment mode for {full_name} ({roll_no})")

    def stop_worker(self):
        logger.info("Stopping camera worker thread...")
        self.running = False
        self.wait(1500)

    def run(self):
        self.running = True
        logger.info(f"Opening camera index {self.camera_index}...")
        cap = cv2.VideoCapture(self.camera_index)
        if not cap.isOpened():
            logger.error(f"Camera index {self.camera_index} could not be opened.")
            return

        fps_timer = time.time()
        frame_counter = 0
        fps = 0.0

        while self.running:
            try:
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
                        if feat is not None:
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
                                logger.info(f"Enrolled {self.enrollment_target['full_name']} successfully.")
                                desktop_event_bus.sync_status_changed.emit(
                                    f"Enrolled {self.enrollment_target['full_name']} ({self.enrollment_target['roll_no']})",
                                    {"action": "ENROLLMENT_COMPLETED"}
                                )
                else:
                    # Live Recognition Mode: Track all visible faces concurrently
                    seen_student_ids: Set[int] = set()

                    for face in faces:
                        try:
                            box = face[0:4].astype(np.int32)
                            x, y, fw, fh = box
                            feat = self.embedder.extract_feature(frame, face)

                            color = (0, 0, 255) # Red default
                            label = "Unknown"

                            if feat is not None:
                                # Cosine vector match against locally enrolled embeddings
                                match_id, sim = self.matcher.find_best_match(feat, self.enrolled_embeddings)

                                if match_id is not None:
                                    seen_student_ids.add(match_id)
                                    details = self.storage.get_student_details(match_id)
                                    name = details[1] if details else f"Student #{match_id}"
                                    roll = details[0] if details else ""

                                    is_confirmed, is_newly_marked = self.tracker.update_student(match_id)

                                    if is_confirmed:
                                        color = (0, 255, 0) # Green confirmed
                                        label = f"{name} ({roll}) [{sim*100:.0f}%]"

                                        if is_newly_marked:
                                            logger.info(f"Emitting attendance_confirmed for {name} ({roll})")
                                            desktop_event_bus.attendance_confirmed.emit(match_id, roll, name, sim)
                                    else:
                                        color = (0, 255, 255) # Yellow verifying
                                        streak = self.tracker.streak_counts.get(match_id, 0)
                                        label = f"Verifying {name} ({streak}/3)..."

                                    detected_summaries.append({"id": match_id, "name": name, "roll": roll, "sim": sim})

                            # Render bounding box and label
                            cv2.rectangle(display_frame, (x, y), (x + fw, y + fh), color, 2)
                            cv2.putText(display_frame, label, (max(0, x), max(20, y - 8)),
                                        cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)
                        except Exception as face_err:
                            logger.warning(f"Error processing face box: {face_err}")

                    # Decay streaks for students not observed in this frame
                    self.tracker.decay_absent_students(seen_student_ids)

                # Publish processed frame to EventBus for UI presentation
                desktop_event_bus.frame_processed.emit(display_frame, detected_summaries, fps)

                # Target ~30 FPS loop rate
                time.sleep(0.01)

            except Exception as loop_err:
                logger.error(f"Unexpected error in camera capture loop: {loop_err}", exc_info=True)
                time.sleep(0.03)

        cap.release()
        logger.info("Camera capture released and worker thread finished.")
