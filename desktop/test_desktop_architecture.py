import sys
import os
from PySide6.QtCore import QCoreApplication

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.events.event_bus import desktop_event_bus
from app.storage.local_db import LocalStorage
from app.controllers.session_controller import SessionController

def test_desktop_mvc_eda():
    print("Testing Desktop MVC + Event-Driven Architecture...")
    app = QCoreApplication.instance() or QCoreApplication(sys.argv)

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

if __name__ == "__main__":
    test_desktop_mvc_eda()
