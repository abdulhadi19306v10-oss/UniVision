from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Student, Teacher
from ..schemas import StudentLogin, TeacherLogin, Token
from ..auth_utils import verify_password, create_access_token
from ..events.event_bus import event_bus

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/student/login", response_model=Token)
async def student_login(credentials: StudentLogin, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.roll_no == credentials.roll_no).first()
    if not student or not verify_password(credentials.password, student.password_hash):
        await event_bus.publish("LoginFailed", {"role": "student", "identifier": credentials.roll_no})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid roll number or password",
        )
    token = create_access_token(data={"sub": student.id, "role": "student", "roll_no": student.roll_no})

    # Publish login event
    await event_bus.publish("StudentLoggedIn", {
        "student_id": student.id,
        "roll_no": student.roll_no,
        "full_name": student.full_name
    })

    return Token(access_token=token, role="student", user_id=student.id, full_name=student.full_name)

@router.post("/teacher/login", response_model=Token)
async def teacher_login(credentials: TeacherLogin, db: Session = Depends(get_db)):
    teacher = db.query(Teacher).filter(Teacher.email == credentials.email).first()
    if not teacher or not verify_password(credentials.password, teacher.password_hash):
        await event_bus.publish("LoginFailed", {"role": "teacher", "identifier": credentials.email})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    token = create_access_token(data={"sub": teacher.id, "role": "teacher", "email": teacher.email})

    # Publish login event
    await event_bus.publish("TeacherLoggedIn", {
        "teacher_id": teacher.id,
        "email": teacher.email,
        "full_name": teacher.full_name
    })

    return Token(access_token=token, role="teacher", user_id=teacher.id, full_name=teacher.full_name)
