from PySide6.QtCore import QObject, Signal

class DesktopEventBus(QObject):
    """
    Decoupled Event Bus for the Edge Windows Desktop Application.
    Uses Qt Signals to provide thread-safe asynchronous messaging between
    background workers (CameraWorker), domain controllers, and UI views.
    """
    # Camera & AI Telemetry Events
    frame_processed = Signal(object, list, float) # (display_frame, faces, fps)
    student_recognized = Signal(int, float) # (student_id, similarity)
    
    # Domain Biometric Confirmation
    attendance_confirmed = Signal(int, str, str, float) # (student_id, roll_no, name, confidence)
    record_queued = Signal(dict) # (record_dict with roll, name, time)
    
    # Session Lifecycle Events
    session_started = Signal(int, str, str) # (local_session_id, course_code, course_name)
    session_ended = Signal(int) # (local_session_id)
    
    # Cloud Synchronization Events
    sync_status_changed = Signal(str, dict) # (status_message, stats_dict)

# Global singleton event bus instance
desktop_event_bus = DesktopEventBus()
