from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from ..database import get_db
from ..models import Session as CourseSession, Course, Teacher
from ..schemas import SessionCreate, SessionOut
from ..auth_utils import get_current_teacher
from ..events.event_bus import event_bus

router = APIRouter(prefix="/sessions", tags=["Sessions"])

@router.post("", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
async def start_session(
    payload: SessionCreate,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    course = db.query(Course).filter(Course.id == payload.course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Course not found")
    if course.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Not authorized for this course")

    new_session = CourseSession(
        course_id=payload.course_id,
        started_at=datetime.now(timezone.utc)
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    # Publish decoupled event to EventBus
    await event_bus.publish("SessionStarted", {
        "session_id": new_session.id,
        "course_id": course.id,
        "course_code": course.code,
        "teacher_id": current_teacher.id,
        "started_at": new_session.started_at.isoformat()
    })

    return new_session

@router.patch("/{session_id}/end", response_model=SessionOut)
async def end_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_teacher: Teacher = Depends(get_current_teacher)
):
    session = db.query(CourseSession).filter(CourseSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.course.teacher_id != current_teacher.id:
        raise HTTPException(status_code=403, detail="Not authorized for this course")

    session.ended_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(session)

    # Publish decoupled event to EventBus
    await event_bus.publish("SessionEnded", {
        "session_id": session.id,
        "course_id": session.course_id,
        "ended_at": session.ended_at.isoformat()
    })

    return session
