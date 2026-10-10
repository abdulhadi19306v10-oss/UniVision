from ..events.event_bus import desktop_event_bus
from ..storage.local_db import LocalStorage
from ..workers.camera_worker import CameraWorker

class EnrollmentController:
    """
    MVC Controller managing student biometric enrollment.
    Instructs the background CameraWorker to collect 5 face samples and save embeddings.
    """
    def __init__(self, storage: LocalStorage, camera_worker: CameraWorker):
        self.storage = storage
        self.camera_worker = camera_worker

    def request_enrollment(self, student_id: int, roll_no: str, full_name: str) -> bool:
        if not student_id or not roll_no or not full_name:
            return False

        if not self.camera_worker.isRunning():
            self.camera_worker.start()

        self.camera_worker.start_enrollment(student_id, roll_no, full_name)
        desktop_event_bus.sync_status_changed.emit(
            f"Capturing biometric samples for {full_name} ({roll_no})...",
            {"action": "ENROLLMENT_STARTED"}
        )
        return True
