import sqlite3
import os
import json
import numpy as np
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

class LocalStorage:
    """
    Offline-first local SQLite storage for the Windows Desktop App.
    Stores biometric embeddings LOCALLY on the machine (they never leave).
    Queues attendance records for offline-first synchronization with the cloud backend.
    """
    def __init__(self, db_path: Optional[str] = None):
        if db_path is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            db_path = os.path.join(base_dir, "desktop_attendance.db")
        self.db_path = db_path
        self._init_db()

    def _get_conn(self):
        return sqlite3.connect(self.db_path)

    def _init_db(self):
        with self._get_conn() as conn:
            cursor = conn.cursor()
            
            # 1. Enrolled students and their biometric embeddings (Local only!)
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS enrolled_students (
                student_id INTEGER PRIMARY KEY,
                roll_no TEXT UNIQUE NOT NULL,
                full_name TEXT NOT NULL,
                embedding BLOB NOT NULL,
                enrolled_at TEXT NOT NULL
            )
            """)

            # 2. Local sessions
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS local_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                course_id INTEGER NOT NULL,
                course_code TEXT NOT NULL,
                course_name TEXT NOT NULL,
                started_at TEXT NOT NULL,
                ended_at TEXT,
                cloud_session_id INTEGER
            )
            """)

            # 3. Attendance sync queue (Offline-first buffer)
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS attendance_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                local_session_id INTEGER NOT NULL,
                cloud_session_id INTEGER,
                student_id INTEGER NOT NULL,
                roll_no TEXT NOT NULL,
                full_name TEXT NOT NULL,
                marked_at TEXT NOT NULL,
                method TEXT DEFAULT 'face',
                confidence REAL,
                synced INTEGER DEFAULT 0,
                synced_at TEXT,
                UNIQUE(local_session_id, student_id)
            )
            """)
            conn.commit()

    # --- Student Biometrics Enrollment ---
    def save_enrolled_student(self, student_id: int, roll_no: str, full_name: str, embedding: np.ndarray):
        raw_bytes = embedding.astype(np.float32).tobytes()
        now_str = datetime.now(timezone.utc).isoformat()
        with self._get_conn() as conn:
            conn.execute("""
            INSERT OR REPLACE INTO enrolled_students (student_id, roll_no, full_name, embedding, enrolled_at)
            VALUES (?, ?, ?, ?, ?)
            """, (student_id, roll_no, full_name, raw_bytes, now_str))
            conn.commit()

    def get_all_enrolled_embeddings(self) -> Dict[int, np.ndarray]:
        """
        Returns {student_id: numpy_embedding} for in-memory matching.
        """
        result = {}
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT student_id, embedding FROM enrolled_students")
            for sid, raw_bytes in cursor.fetchall():
                arr = np.frombuffer(raw_bytes, dtype=np.float32)
                result[sid] = arr
        return result

    def get_student_details(self, student_id: int) -> Optional[Tuple[str, str]]:
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT roll_no, full_name FROM enrolled_students WHERE student_id = ?", (student_id,))
            row = cursor.fetchone()
            return (row[0], row[1]) if row else None

    def list_enrolled_students(self) -> List[dict]:
        with self._get_conn() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT student_id, roll_no, full_name, enrolled_at FROM enrolled_students ORDER BY roll_no")
            return [dict(row) for row in cursor.fetchall()]

    def delete_enrolled_student(self, student_id: int) -> bool:
        """
        Deletes an enrolled student and their biometrics from local database.
        """
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM enrolled_students WHERE student_id = ?", (student_id,))
            conn.commit()
            return cursor.rowcount > 0

    # --- Session Management ---
    def create_local_session(self, course_id: int, course_code: str, course_name: str, cloud_session_id: Optional[int] = None) -> int:
        now_str = datetime.now(timezone.utc).isoformat()
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            INSERT INTO local_sessions (course_id, course_code, course_name, started_at, cloud_session_id)
            VALUES (?, ?, ?, ?, ?)
            """, (course_id, course_code, course_name, now_str, cloud_session_id))
            conn.commit()
            return cursor.lastrowid

    def end_local_session(self, local_session_id: int):
        now_str = datetime.now(timezone.utc).isoformat()
        with self._get_conn() as conn:
            conn.execute("UPDATE local_sessions SET ended_at = ? WHERE id = ?", (now_str, local_session_id))
            conn.commit()

    # --- Attendance Queue (Offline-First) ---
    def queue_attendance(
        self,
        local_session_id: int,
        student_id: int,
        roll_no: str,
        full_name: str,
        method: str = "face",
        confidence: float = 0.9,
        cloud_session_id: Optional[int] = None
    ) -> bool:
        """
        Saves attendance record locally. Returns True if newly added, False if duplicate.
        """
        now_str = datetime.now(timezone.utc).isoformat()
        try:
            with self._get_conn() as conn:
                conn.execute("""
                INSERT INTO attendance_queue 
                (local_session_id, cloud_session_id, student_id, roll_no, full_name, marked_at, method, confidence, synced)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
                """, (local_session_id, cloud_session_id, student_id, roll_no, full_name, now_str, method, confidence))
                conn.commit()
                return True
        except sqlite3.IntegrityError:
            return False

    def get_pending_sync_records(self) -> List[dict]:
        with self._get_conn() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM attendance_queue WHERE synced = 0")
            return [dict(row) for row in cursor.fetchall()]

    def mark_records_synced(self, queue_ids: List[int]):
        now_str = datetime.now(timezone.utc).isoformat()
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.executemany("UPDATE attendance_queue SET synced = 1, synced_at = ? WHERE id = ?",
                               [(now_str, qid) for qid in queue_ids])
            conn.commit()

    def get_session_attendance(self, local_session_id: int) -> List[dict]:
        with self._get_conn() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("""
            SELECT * FROM attendance_queue 
            WHERE local_session_id = ? 
            ORDER BY marked_at DESC
            """, (local_session_id,))
            return [dict(row) for row in cursor.fetchall()]

    def export_session_to_csv(self, local_session_id: int, target_file_path: str):
        import csv
        records = self.get_session_attendance(local_session_id)
        if not records:
            return False
        with open(target_file_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["id", "roll_no", "full_name", "marked_at", "method", "confidence", "synced"])
            writer.writeheader()
            for r in records:
                writer.writerow({
                    "id": r["id"],
                    "roll_no": r["roll_no"],
                    "full_name": r["full_name"],
                    "marked_at": r["marked_at"],
                    "method": r["method"],
                    "confidence": f"{r['confidence']:.2f}" if r['confidence'] else "N/A",
                    "synced": "YES" if r["synced"] == 1 else "PENDING"
                })
        return True

    # ponytail: lightweight queries for desktop views and Flutter bridge
    def list_local_sessions(self) -> List[dict]:
        with self._get_conn() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM local_sessions ORDER BY id DESC")
            return [dict(row) for row in cursor.fetchall()]

    def get_all_attendance(self) -> List[dict]:
        with self._get_conn() as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM attendance_queue ORDER BY id DESC")
            return [dict(row) for row in cursor.fetchall()]

    def update_attendance(self, queue_id: int, method: Optional[str] = None, confidence: Optional[float] = None) -> bool:
        updates = []
        params = []
        if method is not None:
            updates.append("method = ?")
            params.append(method)
        if confidence is not None:
            updates.append("confidence = ?")
            params.append(confidence)
        if not updates:
            return False
        params.append(queue_id)
        with self._get_conn() as conn:
            cursor = conn.cursor()
            cursor.execute(f"UPDATE attendance_queue SET {', '.join(updates)} WHERE id = ?", params)
            conn.commit()
            return cursor.rowcount > 0
