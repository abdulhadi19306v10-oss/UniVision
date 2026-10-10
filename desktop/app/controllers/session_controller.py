from datetime import datetime
from typing import Optional
from ..events.event_bus import desktop_event_bus
from ..storage.local_db import LocalStorage

class SessionController:
    """
    MVC Controller managing lecture session state and attendance buffering.
    Subscribes to EventBus attendance_confirmed signals and safely queues
    records into local SQLite storage.
    """
    def __init__(self, storage: LocalStorage):
        self.storage = storage
        self.active_local_session_id: Optional[int] = None
        self.active_cloud_session_id: Optional[int] = None
        self.active_course_code: str = ""
        self.active_course_name: str = ""

        # Subscribe to EventBus confirmation event
        desktop_event_bus.attendance_confirmed.connect(self.on_attendance_confirmed)

    def start_session(self, course_id: int, course_code: str, course_name: str, cloud_session_id: Optional[int] = None) -> int:
        local_id = self.storage.create_local_session(course_id, course_code, course_name, cloud_session_id)
        self.active_local_session_id = local_id
        self.active_cloud_session_id = cloud_session_id
        self.active_course_code = course_code
        self.active_course_name = course_name

        desktop_event_bus.session_started.emit(local_id, course_code, course_name)
        return local_id

    def end_session(self) -> Optional[int]:
        if self.active_local_session_id is not None:
            sid = self.active_local_session_id
            self.storage.end_local_session(sid)
            self.active_local_session_id = None
            desktop_event_bus.session_ended.emit(sid)
            return sid
        return None

    def on_attendance_confirmed(self, student_id: int, roll_no: str, full_name: str, confidence: float):
        """
        Event subscriber callback: Invoked when the AI camera worker reaches 3 consecutive matches.
        """
        if self.active_local_session_id is not None:
            is_new = self.storage.queue_attendance(
                local_session_id=self.active_local_session_id,
                student_id=student_id,
                roll_no=roll_no,
                full_name=full_name,
                method="face",
                confidence=confidence,
                cloud_session_id=self.active_cloud_session_id
            )
            if is_new:
                record_dict = {
                    "student_id": student_id,
                    "roll_no": roll_no,
                    "full_name": full_name,
                    "time": datetime.now().strftime("%H:%M:%S"),
                    "confidence": confidence
                }
                desktop_event_bus.record_queued.emit(record_dict)
