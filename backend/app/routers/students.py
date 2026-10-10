from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models import Attendance, Course, Session as CourseSession, Enrollment, Student
from ..schemas import StudentAttendanceItem, CourseSummary
from ..auth_utils import get_current_student

router = APIRouter(prefix="/me", tags=["Student Self-Service"])

@router.get("/attendance", response_model=List[StudentAttendanceItem])
def get_my_attendance(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    attendances = db.query(Attendance).filter(Attendance.student_id == current_student.id).all()
    results = []
    for att in attendances:
        session = att.session
        course = session.course
        results.append(StudentAttendanceItem(
            attendance_id=att.id,
            course_code=course.code,
            course_name=course.name,
            session_id=session.id,
            marked_at=att.marked_at,
            method=att.method
        ))
    return results

@router.get("/summary", response_model=List[CourseSummary])
def get_my_attendance_summary(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    # Get courses the student is enrolled in
    enrollments = db.query(Enrollment).filter(Enrollment.student_id == current_student.id).all()
    summaries = []

    for enr in enrollments:
        course = enr.course
        total_sessions = db.query(CourseSession).filter(CourseSession.course_id == course.id).count()

        # Count how many sessions attended
        attended_count = db.query(Attendance).join(CourseSession).filter(
            CourseSession.course_id == course.id,
            Attendance.student_id == current_student.id
        ).count()

        pct = (attended_count / total_sessions * 100.0) if total_sessions > 0 else 100.0
        is_below = pct < 75.0

        summaries.append(CourseSummary(
            course_id=course.id,
            course_code=course.code,
            course_name=course.name,
            total_sessions=total_sessions,
            attended_sessions=attended_count,
            attendance_percentage=round(pct, 2),
            is_below_threshold=is_below
        ))

    return summaries
