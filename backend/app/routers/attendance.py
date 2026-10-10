from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone
from typing import List
from ..database import get_db
from ..models import Attendance, Session as CourseSession, Teacher
from ..schemas import AttendanceBatchUpload, AttendanceUpdate, AttendanceOut
from ..auth_utils import get_current_teacher
from ..events.event_bus import event_bus

router = APIRouter(prefix="/attendance", tags=["Attendance"])

@router.post("/batch", response_model=List[AttendanceOut], status_code=status.HTTP_200_OK)
async def upload_batch_attendance(
    payload: AttendanceBatchUpload,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    """
    MVC Controller: Validates teacher access, persists batch records,
    and publishes BatchAttendanceReceived event to the EventBus for decoupled
    asynchronous audit logging, telemetry, and student push notifications.
    """
    session = db.query(CourseSession).filter(CourseSession.id == payload.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Attendance session not found")
    if session.course.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Not authorized to submit attendance for this course")

    saved_records = []
    for rec in payload.records:
        existing = db.query(Attendance).filter(
            Attendance.session_id == payload.session_id,
            Attendance.student_id == rec.student_id
        ).first()

        if existing:
            saved_records.append(existing)
            continue

        marked_time = rec.marked_at or datetime.now(timezone.utc)
        new_att = Attendance(
            session_id=payload.session_id,
            student_id=rec.student_id,
            marked_at=marked_time,
            method=rec.method or "face",
            confidence=rec.confidence
        )
        db.add(new_att)
        try:
            db.commit()
            db.refresh(new_att)
            saved_records.append(new_att)
        except IntegrityError:
            db.rollback()
            existing = db.query(Attendance).filter(
                Attendance.session_id == payload.session_id,
                Attendance.student_id == rec.student_id
            ).first()
            if existing:
                saved_records.append(existing)

    # Publish decoupled domain event to EventBus for audit logging & push alerts
    batch_dict = {
        "session_id": payload.session_id,
        "teacher_id": current_teacher.id,
        "course_id": session.course_id,
        "records": [r.model_dump() for r in payload.records]
    }
    await event_bus.publish("BatchAttendanceReceived", batch_dict)

    return saved_records

@router.patch("/{attendance_id}", response_model=AttendanceOut)
async def manual_attendance_correction(
    attendance_id: int,
    payload: AttendanceUpdate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    att = db.query(Attendance).filter(Attendance.id == attendance_id).first()
    if not att:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    if att.session.course.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Not authorized for this course")

    if payload.method:
        att.method = payload.method
    if payload.confidence is not None:
        att.confidence = payload.confidence

    db.commit()
    db.refresh(att)

    await event_bus.publish("AttendanceCorrected", {
        "attendance_id": att.id,
        "teacher_id": current_teacher.id,
        "new_method": att.method,
        "new_confidence": att.confidence
    })

    return att
