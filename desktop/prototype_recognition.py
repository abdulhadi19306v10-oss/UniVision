import cv2
import numpy as np
import time
import os
import sys

# Ensure desktop/ is in sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.recognition.detector import YuNetDetector
from app.recognition.embedder import SFaceEmbedder
from app.recognition.matcher import CosineMatcher
from app.recognition.tracker import ConsecutiveFrameTracker
from app.recognition.liveness import LivenessDetector
from app.storage.local_db import LocalStorage

def run_prototype():
    print("=" * 60)
    print("👁️ Focus Face Recognition Attendance — Step 1 Prototype")
    print("Models: YuNet (Detection) + SFace (Embeddings) on CPU")
    print("=" * 60)

    storage = LocalStorage()
    detector = YuNetDetector()
    embedder = SFaceEmbedder()
    matcher = CosineMatcher(threshold=0.363)
    tracker = ConsecutiveFrameTracker(required_consecutive_frames=3)
    liveness = LivenessDetector()

    enrolled_faces = storage.get_all_enrolled_embeddings()
    print(f"Loaded {len(enrolled_faces)} enrolled students from local storage.")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("❌ Could not open webcam (index 0). Please check your camera connection.")
        return

    print("\nControls:")
    print(" [E] - Enroll a new student (Captures 5 sample frames)")
    print(" [L] - List currently enrolled students")
    print(" [R] - Reset session tracking")
    print(" [Q] - Quit prototype")
    print("\nStarting video stream...")

    fps_time = time.time()
    frame_count = 0
    fps = 0.0

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame.")
            break

        frame_count += 1
        if time.time() - fps_time >= 1.0:
            fps = frame_count / (time.time() - fps_time)
            fps_time = time.time()
            frame_count = 0

        display_frame = frame.copy()
        h, w = frame.shape[:2]

        # 1. Detect faces via YuNet
        faces = detector.detect(frame)
        best_id_this_frame = None

        if len(faces) > 0:
            for face in faces:
                box = face[0:4].astype(np.int32)
                score = face[14]
                x, y, fw, fh = box

                # 2. Extract embedding via SFace
                feat = embedder.extract_feature(frame, face)

                # 3. Match against enrolled
                match_id, sim = matcher.find_best_match(feat, enrolled_faces)

                # 4. Anti-spoofing check
                is_live, live_score = liveness.check_liveness(frame, face)

                # Visual bounding box and label
                color = (0, 0, 255) # Red default
                label = "Unknown"

                if match_id is not None:
                    details = storage.get_student_details(match_id)
                    name = details[1] if details else f"Student #{match_id}"
                    roll = details[0] if details else ""

                    # 5. Consecutive frame confirmation
                    best_id_this_frame = match_id
                    confirmed_id, is_newly_marked = tracker.update(match_id)

                    if confirmed_id:
                        color = (0, 255, 0) # Green confirmed
                        label = f"{name} ({roll}) [{sim*100:.1f}%]"
                        if is_newly_marked:
                            print(f"\n✅ ATTENDANCE CONFIRMED: {name} ({roll}) at {time.strftime('%X')}")
                    else:
                        color = (0, 255, 255) # Yellow verifying
                        label = f"Verifying {name}... ({tracker.streak_counts.get(match_id, 0)}/3)"
                else:
                    tracker.update(None)

                # Draw bounding box
                cv2.rectangle(display_frame, (x, y), (x + fw, y + fh), color, 2)
                
                # Draw landmarks (eyes, nose, mouth)
                for i in range(5):
                    lx, ly = int(face[4 + 2 * i]), int(face[5 + 2 * i])
                    cv2.circle(display_frame, (lx, ly), 2, (255, 0, 0), 2)

                # Label background & text
                cv2.rectangle(display_frame, (x, y - 25), (x + fw, y), color, -1)
                cv2.putText(display_frame, label, (x + 5, y - 7), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)

        else:
            tracker.update(None)

        # Telemetry overlay
        cv2.putText(display_frame, f"FPS: {fps:.1f} | Enrolled: {len(enrolled_faces)}", (10, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        cv2.putText(display_frame, "Keys: [E] Enroll  [R] Reset  [Q] Quit", (10, h - 15),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

        cv2.imshow("Face Recognition Attendance (Step 1 Prototype)", display_frame)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q') or key == 27:
            break
        elif key == ord('r'):
            tracker.reset_session()
            print("Session attendance buffer reset.")
        elif key == ord('l'):
            students = storage.list_enrolled_students()
            print("\n--- Enrolled Students ---")
            for s in students:
                print(f" ID: {s['student_id']} | Roll: {s['roll_no']} | Name: {s['full_name']}")
            print("-------------------------\n")
        elif key == ord('e'):
            # Interactive enrollment
            print("\n--- Student Enrollment ---")
            try:
                sid_str = input("Enter Cloud Student ID (integer): ").strip()
                if not sid_str:
                    continue
                sid = int(sid_str)
                roll = input("Enter Roll Number (e.g. 2024-CS-001): ").strip()
                name = input("Enter Full Name: ").strip()

                print("Capturing 5 sample frames for biometric averaging...")
                captured_feats = []
                while len(captured_feats) < 5:
                    ret_e, frame_e = cap.read()
                    if not ret_e:
                        continue
                    faces_e = detector.detect(frame_e)
                    if len(faces_e) == 1:
                        f_emb = embedder.extract_feature(frame_e, faces_e[0])
                        captured_feats.append(f_emb)
                        print(f" Captured sample {len(captured_feats)}/5")
                        time.sleep(0.3)
                    elif len(faces_e) > 1:
                        print(" Warning: multiple faces detected, skipping frame.")
                        time.sleep(0.3)

                avg_embedding = embedder.average_embeddings(captured_feats)
                storage.save_enrolled_student(sid, roll, name, avg_embedding)
                enrolled_faces = storage.get_all_enrolled_embeddings()
                print(f"🎉 Successfully enrolled {name} ({roll})!\n")
            except Exception as e:
                print(f"Enrollment aborted or failed: {e}")

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    run_prototype()
