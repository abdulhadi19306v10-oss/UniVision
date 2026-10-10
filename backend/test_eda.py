import asyncio
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.events.event_bus import event_bus
from app.events import handlers
from app.database import SessionLocal, engine
from app.models import Base, AuditLog, Session as CourseSession, Student, Attendance
from datetime import datetime, timezone

async def test_backend_eda():
    print("Testing Backend Event-Driven Architecture (EDA)...")
    Base.metadata.create_all(bind=engine)

    # Start event processing task
    worker = asyncio.create_task(event_bus.start_processing())
    await asyncio.sleep(0.1)

    db = SessionLocal()
    session = db.query(CourseSession).first()
    student = db.query(Student).first()
    db.close()

    assert session is not None, "Sample session must exist"
    assert student is not None, "Sample student must exist"

    # Test 1: Publish TeacherLoggedIn
    await event_bus.publish("TeacherLoggedIn", {
        "teacher_id": 1,
        "email": "teacher@school.edu",
        "full_name": "Prof. Alan Turing"
    })

    # Test 2: Publish BatchAttendanceReceived
    await event_bus.publish("BatchAttendanceReceived", {
        "session_id": session.id,
        "records": [
            {
                "student_id": student.id,
                "marked_at": datetime.now(timezone.utc).isoformat(),
                "method": "face",
                "confidence": 0.95
            }
        ]
    })

    # Allow async handlers to process
    await asyncio.sleep(0.5)

    # Verify AuditLog has recorded the events
    db = SessionLocal()
    audit_count = db.query(AuditLog).count()
    print(f"Audit log rows recorded by event bus: {audit_count}")
    assert audit_count > 0, "Audit handler should have created audit logs"

    # Check last audit log
    last_log = db.query(AuditLog).order_by(AuditLog.id.desc()).first()
    print(f"Latest audit action: {last_log.action}")
    db.close()

    # Stop worker
    event_bus.stop_processing()
    worker.cancel()
    print("[PASSED] Backend EDA test PASSED successfully!")

if __name__ == "__main__":
    asyncio.run(test_backend_eda())
