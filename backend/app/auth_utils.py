import os
from datetime import datetime, timedelta, timezone
from typing import Optional
try:
    from jose import JWTError, jwt
except ImportError:
    import jwt
    from jwt.exceptions import PyJWTError as JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from .database import get_db
from .models import Student, Teacher

SECRET_KEY = os.getenv("SECRET_KEY", "focus-attendance-super-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # 7 days

import bcrypt

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

def get_password_hash(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

security_bearer = HTTPBearer()

def decode_token(credentials: HTTPAuthorizationCredentials = Depends(security_bearer)) -> dict:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_teacher(payload: dict = Depends(decode_token), db: Session = Depends(get_db)) -> Teacher:
    if payload.get("role") != "teacher":
        raise HTTPException(status_code=403, detail="Teacher credentials required")
    teacher = db.query(Teacher).filter(Teacher.id == payload.get("sub")).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="Teacher not found")
    return teacher

def get_current_student(payload: dict = Depends(decode_token), db: Session = Depends(get_db)) -> Student:
    if payload.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student credentials required")
    student = db.query(Student).filter(Student.id == payload.get("sub")).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return student
