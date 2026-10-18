import sys
import os
try:
    from PyQt6.QtWidgets import QApplication
except ImportError:
    from PySide6.QtWidgets import QApplication

# ponytail: robust desktop module resolution preventing root test import collision
desktop_dir = os.path.dirname(os.path.abspath(__file__))
if desktop_dir not in sys.path:
    sys.path.insert(0, desktop_dir)

try:
    from desktop.app.events.event_bus import desktop_event_bus
    from desktop.app.storage.local_db import LocalStorage
    from desktop.app.controllers.session_controller import SessionController
    from desktop.app.recognition.tracker import ConsecutiveFrameTracker
except ImportError:
    from app.events.event_bus import desktop_event_bus
    from app.storage.local_db import LocalStorage
    from app.controllers.session_controller import SessionController
    from app.recognition.tracker import ConsecutiveFrameTracker

def test_desktop_mvc_eda():
    print("Testing Desktop MVC + Event-Driven Architecture...")
    app = QApplication.instance() or QApplication(sys.argv)

    test_db = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_desktop.db")
    if os.path.exists(test_db):
        os.remove(test_db)
    storage = LocalStorage(db_path=test_db)
    session_ctrl = SessionController(storage)

    events_received = []

    def on_session_started(sid, code, name):
        events_received.append(("SESSION_STARTED", sid, code, name))

    def on_record_queued(rec):
        events_received.append(("RECORD_QUEUED", rec["roll_no"], rec["full_name"]))

    desktop_event_bus.session_started.connect(on_session_started)
    desktop_event_bus.record_queued.connect(on_record_queued)

    # 1. Controller starts session
    session_id = session_ctrl.start_session(course_id=101, course_code="CS-401", course_name="Architecture")
    assert session_id == 1
    assert len(events_received) == 1
    assert events_received[0] == ("SESSION_STARTED", 1, "CS-401", "Architecture")
    print("[PASS] SessionController emitted session_started event through DesktopEventBus.")

    # 2. Simulate AI worker emitting attendance_confirmed event
    desktop_event_bus.attendance_confirmed.emit(10, "2024-CS-001", "Alice Johnson", 0.94)

    # Allow Qt signal processing
    app.processEvents()

    assert len(events_received) == 2
    assert events_received[1] == ("RECORD_QUEUED", "2024-CS-001", "Alice Johnson")
    print("[PASS] AttendanceConfirmed event automatically buffered in LocalStorage and emitted record_queued.")

    # 3. Verify SQLite queue
    records = storage.get_session_attendance(1)
    assert len(records) == 1
    assert records[0]["roll_no"] == "2024-CS-001"
    print("[PASS] Local SQLite queue contains confirmed record.")

    session_ctrl.end_session()
    del session_ctrl
    del storage
    import gc
    gc.collect()
    try:
        if os.path.exists(test_db):
            os.remove(test_db)
    except Exception:
        pass
    print("[PASSED] Desktop MVC + EDA test PASSED successfully!")

def test_tracker_multi_face():
    print("Testing ConsecutiveFrameTracker multi-face concurrent tracking...")
    tracker = ConsecutiveFrameTracker(required_consecutive_frames=3, max_idle_decay=2)

    # Frame 1: Student 10 and 20 present
    c1, n1 = tracker.update_student(10)
    c2, n2 = tracker.update_student(20)
    tracker.decay_absent_students({10, 20})
    assert not c1 and not n1
    assert not c2 and not n2

    # Frame 2: Student 10 and 20 present
    c1, n1 = tracker.update_student(10)
    c2, n2 = tracker.update_student(20)
    tracker.decay_absent_students({10, 20})
    assert not c1 and not c2

    # Frame 3: Both reach streak 3 -> confirmed & newly marked
    c1, n1 = tracker.update_student(10)
    c2, n2 = tracker.update_student(20)
    tracker.decay_absent_students({10, 20})
    assert c1 and n1
    assert c2 and n2

    # Frame 4: Student 10 still present, Student 20 absent
    c1, n1 = tracker.update_student(10)
    tracker.decay_absent_students({10})
    assert c1 and not n1 # Confirmed, but not newly marked

    # Frame 5 & 6: Student 20 still absent -> decayed
    tracker.decay_absent_students({10})
    tracker.decay_absent_students({10})
    assert tracker.streak_counts.get(20, 0) == 0

    # Reset session
    tracker.reset_session()
    assert len(tracker.streak_counts) == 0
    assert len(tracker.confirmed_this_session) == 0
    print("[PASSED] ConsecutiveFrameTracker multi-face tracking PASSED successfully!")

def test_enrollment_and_deletion():
    print("Testing Student Enrollment and Deletion in LocalStorage...")
    import numpy as np
    test_db = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_del.db")
    if os.path.exists(test_db):
        os.remove(test_db)
    storage = LocalStorage(db_path=test_db)

    # Save a mock student
    dummy_emb = np.random.rand(128).astype(np.float32)
    storage.save_enrolled_student(student_id=77, roll_no="2024-CS-077", full_name="John Doe", embedding=dummy_emb)

    students = storage.list_enrolled_students()
    assert len(students) == 1
    assert students[0]["student_id"] == 77
    assert students[0]["full_name"] == "John Doe"

    # Delete the student
    deleted = storage.delete_enrolled_student(77)
    assert deleted is True

    # Verify student is removed
    students_after = storage.list_enrolled_students()
    assert len(students_after) == 0
    del storage
    import gc
    gc.collect()

    try:
        if os.path.exists(test_db):
            os.remove(test_db)
    except Exception:
        pass
    print("[PASSED] Student Enrollment and Deletion PASSED successfully!")

if __name__ == "__main__":
    test_desktop_mvc_eda()
    test_tracker_multi_face()
    test_enrollment_and_deletion()
