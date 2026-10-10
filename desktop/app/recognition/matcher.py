import numpy as np
from typing import Dict, Tuple, Optional

class CosineMatcher:
    """
    Performs vector cosine matching between live embeddings and locally enrolled embeddings.
    """
    def __init__(self, threshold: float = 0.363):
        # Default threshold for SFace Cosine distance is 0.363 (cosine similarity >= 0.637)
        self.threshold = threshold

    @staticmethod
    def cosine_similarity(v1: np.ndarray, v2: np.ndarray) -> float:
        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)
        if norm1 == 0 or norm2 == 0:
            return 0.0
        return float(np.dot(v1, v2) / (norm1 * norm2))

    def find_best_match(
        self,
        query_embedding: np.ndarray,
        enrolled_db: Dict[int, np.ndarray]
    ) -> Tuple[Optional[int], float]:
        """
        Compares query_embedding against all enrolled embeddings in enrolled_db {student_id: embedding}.
        Returns (best_student_id, best_similarity).
        If best_similarity does not meet threshold, returns (None, best_similarity).
        """
        if not enrolled_db:
            return None, 0.0

        best_student_id = None
        best_sim = -1.0

        for student_id, enrolled_emb in enrolled_db.items():
            sim = self.cosine_similarity(query_embedding, enrolled_emb)
            if sim > best_sim:
                best_sim = sim
                best_student_id = student_id

        # Convert distance threshold to similarity equivalent
        min_sim_required = 1.0 - self.threshold # e.g. 1.0 - 0.363 = 0.637

        if best_sim >= min_sim_required:
            return best_student_id, best_sim
        else:
            return None, best_sim
