import logging
from typing import Dict, Optional, Set, Tuple

logger = logging.getLogger("Tracker")

class ConsecutiveFrameTracker:
    """
    Guarantees identification stability by requiring a student to be recognized
    across N consecutive frames before officially confirming and marking attendance.
    Supports tracking multiple faces simultaneously without cross-talk or streak wipeout.
    """
    def __init__(self, required_consecutive_frames: int = 3, max_idle_decay: int = 5):
        self.required_consecutive_frames = required_consecutive_frames
        self.max_idle_decay = max_idle_decay
        self.streak_counts: Dict[int, int] = {}
        self.idle_frames: Dict[int, int] = {}
        self.confirmed_this_session: Set[int] = set()

    def update_student(self, student_id: int) -> Tuple[bool, bool]:
        """
        Updates streak for a specific student observed in the current frame.
        Returns: (is_confirmed, is_newly_confirmed)
        """
        current_streak = self.streak_counts.get(student_id, 0) + 1
        self.streak_counts[student_id] = current_streak
        self.idle_frames[student_id] = 0

        is_confirmed = (current_streak >= self.required_consecutive_frames)
        is_newly_confirmed = False

        if is_confirmed and student_id not in self.confirmed_this_session:
            is_newly_confirmed = True
            self.confirmed_this_session.add(student_id)
            logger.info(f"Student #{student_id} confirmed (streak: {current_streak})")

        return is_confirmed, is_newly_confirmed

    def decay_absent_students(self, seen_student_ids: Set[int]):
        """
        Decays streaks for any tracked students who were NOT present in this frame.
        """
        for sid in list(self.streak_counts.keys()):
            if sid not in seen_student_ids:
                self.idle_frames[sid] = self.idle_frames.get(sid, 0) + 1
                if self.idle_frames[sid] >= self.max_idle_decay:
                    self.streak_counts[sid] = 0

    def is_already_marked(self, student_id: int) -> bool:
        return student_id in self.confirmed_this_session

    def reset_session(self):
        logger.info("Resetting tracker session state.")
        self.streak_counts.clear()
        self.idle_frames.clear()
        self.confirmed_this_session.clear()

