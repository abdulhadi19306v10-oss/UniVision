import logging
from datetime import datetime, timezone
from sqlalchemy.exc import IntegrityError
from ..event_bus import event_bus
from ...database import SessionLocal
from ...models import Attendance, Student, Session as CourseSession

logger = logging.getLogger("backend.handlers.attendance")

async def handle_batch_attendance(payload: dict):
    """
    Asynchronously processes batch attendance records received from the edge desktop client.
    Handles deduplication and database persistence, then publishes downstream events.
    """
    session_id = payload.get("session_id")
    records = payload.get("records", [])

    if not session_id or not records:
        return

    db = SessionLocal()
    try:
        session = db.query(CourseSession).filter(CourseSession.id == session_id).first()
        if not session:
            logger.error(f"[AttendanceHandler] Session {session_id} not found.")
            return

        course_code = session.course.code if session.course else "UNKNOWN"
        course_name = session.course.name if session.course else "UNKNOWN"

        for rec in records:
            student_id = rec.get("student_id")
            if not student_id:
                continue

            # Idempotency check: see if record already marked
            existing = db.query(Attendance).filter(
                Attendance.session_id == session_id,
                Attendance.student_id == student_id
            ).first()

            if existing:
                continue

            marked_at_raw = rec.get("marked_at")
            if marked_at_raw:
                try:
                    marked_time = datetime.fromisoformat(marked_at_raw.replace("Z", "+00:00"))
                except Exception:
                    marked_time = datetime.now(timezone.utc)
            else:
                marked_time = datetime.now(timezone.utc)

            new_attendance = Attendance(
                session_id=session_id,
                student_id=student_id,
                marked_at=marked_time,
                method=rec.get("method", "face"),
                confidence=rec.get("confidence")
            )
            db.add(new_attendance)

            try:
                db.commit()
                db.refresh(new_attendance)

                # Fetch student info
                student = db.query(Student).filter(Student.id == student_id).first()
                roll_no = student.roll_no if student else "N/A"
                full_name = student.full_name if student else "N/A"

                # Publish domain event for audit logging and mobile notifications
                await event_bus.publish("AttendanceMarked", {
                    "attendance_id": new_attendance.id,
                    "session_id": session_id,
                    "student_id": student_id,
                    "roll_no": roll_no,
                    "full_name": full_name,
                    "course_code": course_code,
                    "course_name": course_name,
                    "marked_at": new_attendance.marked_at.isoformat(),
                    "method": new_attendance.method,
                    "confidence": new_attendance.confidence
                })

            except IntegrityError:
                db.rollback()
                logger.info(f"[AttendanceHandler] Duplicate attendance suppressed for student {student_id}")
            except Exception as e:
                db.rollback()
                logger.error(f"[AttendanceHandler] Failed to save attendance for student {student_id}: {e}")

    finally:
        db.close()

# Register subscriber
event_bus.subscribe("BatchAttendanceReceived", handle_batch_attendance)
