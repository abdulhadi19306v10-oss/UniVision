from typing import Dict, Optional, Set, Tuple

class ConsecutiveFrameTracker:
    """
    Guarantees identification stability by requiring a student to be recognized
    across N consecutive frames before officially confirming and marking attendance.
    Prevents instantaneous false positives and glitched detections.
    """
    def __init__(self, required_consecutive_frames: int = 3, max_idle_decay: int = 5):
        self.required_consecutive_frames = required_consecutive_frames
        self.max_idle_decay = max_idle_decay
        self.streak_counts: Dict[int, int] = {}
        self.idle_frames: Dict[int, int] = {}
        self.confirmed_this_session: Set[int] = set()

    def update(self, detected_student_id: Optional[int]) -> Tuple[Optional[int], bool]:
        """
        Updates consecutive frame tracker with the current frame's detected student ID.
        Returns (student_id, is_newly_confirmed).
        """
        newly_confirmed = False
        active_id = None

        if detected_student_id is not None:
            # Increment candidate streak
            current_streak = self.streak_counts.get(detected_student_id, 0) + 1
            self.streak_counts[detected_student_id] = current_streak
            self.idle_frames[detected_student_id] = 0

            # Check if threshold reached
            if current_streak >= self.required_consecutive_frames:
                active_id = detected_student_id
                if detected_student_id not in self.confirmed_this_session:
                    newly_confirmed = True
                    self.confirmed_this_session.add(detected_student_id)
        else:
            # Decay streaks when no face or unknown face is found
            for sid in list(self.streak_counts.keys()):
                self.idle_frames[sid] = self.idle_frames.get(sid, 0) + 1
                if self.idle_frames[sid] >= self.max_idle_decay:
                    self.streak_counts[sid] = 0

        return active_id, newly_confirmed

    def is_already_marked(self, student_id: int) -> bool:
        return student_id in self.confirmed_this_session

    def reset_session(self):
        self.streak_counts.clear()
        self.idle_frames.clear()
        self.confirmed_this_session.clear()
