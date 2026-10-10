# 🎓 Focus: Privacy-Preserving Face Recognition Attendance System

[![Architecture](https://img.shields.io/badge/Architecture-Edge--Cloud%20Tri--Tier-indigo?style=for-the-badge)](focus.md)
[![Edge AI](https://img.shields.io/badge/Edge%20AI-OpenCV%20YuNet%20%2B%20SFace%20(ONNX)-green?style=for-the-badge)](desktop/)
[![Backend](https://img.shields.io/badge/Cloud%20API-FastAPI%20%2B%20PostgreSQL-teal?style=for-the-badge)](backend/)
[![Mobile](https://img.shields.io/badge/Mobile-Flutter-blue?style=for-the-badge)](mobile/)

---

## 📌 1. Overview & Core Philosophy

**Focus Attendance** is an automated, privacy-first facial recognition attendance system designed for educational institutions.

### 🛡️ Fundamental Design Principle
> **Biometric data never leaves the classroom PC.**  
> Face images and 128-dimensional embedding vectors are captured, stored, and matched **locally** inside an encrypted SQLite database on the Windows machine. The cloud backend **never** sees or stores biometric embeddings—it only receives minimal attendance records (`student_id`, `session_id`, `timestamp`, `method`, `confidence`).

```
[Camera] ──> [Windows App: Detect (YuNet) + Embed (SFace) + Match (Local)]
                         │
                         │ (Attendance records ONLY)
                         ▼
                 [FastAPI Backend] <───> [Neon Postgres]
                         ▲
                         │ (HTTPS + JWT)
                         │
                [Mobile App: Students]
```

---

## 🏗️ 2. System Architecture: Strict Hybrid (MVC + Event-Driven)

The system strictly adheres to a **Hybrid Architecture** combining **Model-View-Controller (MVC)** with an asynchronous **Event-Driven Architecture (EDA)** across both the Edge Client and Cloud Server.

```mermaid
graph TD
    subgraph DesktopApp ["Desktop App (Edge PC) — Hybrid MVC + EDA"]
        View_Qt["PySide6 Views (HUD, Roster, Setup, Sync)"]
        Ctrl_Qt["Controllers (Session, Enrollment, Sync)"]
        Model_Qt[("Local SQLite Storage (Embeddings & Queue)")]
        Bus_Qt(("DesktopEventBus (Qt Signals)"))
        Worker_Qt["Camera & AI Worker (Dedicated QThread)"]

        View_Qt -->|User Action| Ctrl_Qt
        Ctrl_Qt -->|Command| Worker_Qt
        Worker_Qt -->|Publish: frame_processed| Bus_Qt
        Worker_Qt -->|Publish: attendance_confirmed| Bus_Qt
        Bus_Qt -->|Subscribe| Ctrl_Qt
        Bus_Qt -->|Subscribe| View_Qt
        Ctrl_Qt -->|Persist Queue| Model_Qt
    end

    subgraph CloudBackend ["Cloud Backend API — Hybrid MVC + EDA"]
        Route_FastAPI["FastAPI Routers (MVC Controllers)"]
        Model_Cloud[("Neon Postgres (Models)")]
        Bus_Cloud(("Async EventBus (asyncio.Queue)"))
        Handler_Att["Attendance Persistence Handler"]
        Handler_Audit["Audit Log Handler"]
        Handler_Notify["Notification WebSocket Dispatcher"]

        Route_FastAPI -->|Publish: BatchAttendanceReceived| Bus_Cloud
        Bus_Cloud -->|Dispatch| Handler_Att
        Bus_Cloud -->|Dispatch| Handler_Audit
        Bus_Cloud -->|Dispatch| Handler_Notify
        Handler_Att -->|Commit| Model_Cloud
        Handler_Audit -->|Commit| Model_Cloud
    end

    Ctrl_Qt -->|HTTP POST /attendance/batch| Route_FastAPI
    Handler_Notify -.->|Real-Time Push Alerts (WS)| MobileApp["Student Mobile App (Flutter)"]
```

| Layer | Model | View | Controller | Event-Driven Mechanism |
|---|---|---|---|---|
| **Edge Desktop App** | `LocalStorage` (SQLite) | `MainWindow` (PySide6 UI) | `SessionController`, `SyncController`, `EnrollmentController` | `DesktopEventBus` + `CameraWorker` (`QThread`) |
| **Cloud Backend** | SQLAlchemy (`models.py`) | Pydantic DTOs (`schemas.py`) | FastAPI Routers (`routers/`) | `AsyncEventBus` (`asyncio.Queue`) + Handlers |
| **Mobile Client** | `attendance_model.dart` | Flutter Widgets (`screens/`) | `ApiService` | WebSocket Push Receiver (`/ws/student/{id}`) |

---

## 🧠 3. Edge Biometric Pipeline

The local recognition pipeline is designed for high-speed CPU performance without requiring high-end GPUs:

1. **Detection:** OpenCV **YuNet** (`face_detection_yunet_2023mar.onnx`) running at 100+ FPS on CPU.
2. **Embedding:** OpenCV **SFace** (`face_recognition_sface_2021dec.onnx`) generating 128-d L2-normalized feature vectors.
3. **Centroid Enrollment:** Captures 5 sample frames per student with varied angles, computing an averaged centroid embedding: $\mathbf{v}_{\text{profile}} = \frac{1}{K}\sum \mathbf{v}_k$.
4. **Cosine Similarity Matching:** Measures vector distance against locally enrolled students with standard cosine threshold.
5. **Temporal Consecutive-Frame Confirmation:** Requires $N = 3$ consecutive frames of matching before officially confirming presence, eliminating momentary false positives.
6. **Liveness / Anti-Spoofing:** Tracks landmark micro-dynamics across frames to defeat static printed photo attacks.
7. **Offline-First Storage:** Records are stored in a local SQLite queue first. If internet drops, records buffer safely and sync automatically once online.

---

## 📂 4. Project Structure

```text
lab 3/
├── focus.md                        # Master product specification & requirements
├── README.md                       # Complete system documentation (this file)
│
├── desktop/                        # Windows Native Application (Edge AI)
│   ├── prototype_recognition.py    # Step 1 Standalone Recognition Prototype
│   ├── requirements.txt            # Desktop dependencies (PySide6, OpenCV, ONNX)
│   ├── models/                     # Downloaded ONNX Model weights
│   │   ├── face_detection_yunet_2023mar.onnx
│   │   └── face_recognition_sface_2021dec.onnx
│   └── app/
│       ├── main.py                 # PySide6 application launcher
│       ├── recognition/            # Detection, embedding, matching, tracking, liveness
│       │   ├── detector.py         # YuNet detector wrapper
│       │   ├── embedder.py         # SFace feature extractor
│       │   ├── matcher.py          # Vector cosine matcher
│       │   ├── tracker.py          # Consecutive frame confirmation tracker
│       │   └── liveness.py         # Anti-spoofing micro-motion checker
│       ├── storage/                # Local database & cloud sync
│       │   ├── local_db.py         # Local SQLite storage & offline queue
│       │   └── sync_client.py      # HTTP batch synchronizer to FastAPI
│       └── ui/
│           └── main_window.py      # Multi-tab PySide6 UI (Live, Enroll, Setup, Records, Sync)
│
├── backend/                        # Cloud FastAPI Service
│   ├── requirements.txt            # Backend dependencies
│   ├── seed_data.py                # Database seeder (teachers, students, courses)
│   ├── .env.example                # Environment configuration
│   └── app/
│       ├── main.py                 # FastAPI entry point & CORS
│       ├── database.py             # Neon Postgres & dev SQLite engine
│       ├── models.py               # SQLAlchemy schema models (matches focus.md)
│       ├── schemas.py              # Pydantic DTOs
│       ├── auth_utils.py           # Bcrypt & JWT token management
│       └── routers/
│           ├── auth.py             # Student and teacher login
│           ├── sessions.py         # Start & end lecture sessions
│           ├── attendance.py       # Batch attendance sync & manual corrections
│           └── students.py         # /me/attendance & /me/summary endpoints
│
└── mobile/                         # Flutter Student Mobile App
    ├── pubspec.yaml                # Flutter dependencies
    └── lib/
        ├── main.dart               # Mobile entry point
        ├── models/                 # Data models (CourseSummary, AttendanceItem)
        ├── services/               # HTTP client to FastAPI backend
        └── screens/
            ├── login_screen.dart   # Student login with roll number
            └── dashboard_screen.dart # Course percentages & history log
```

---

## 🚀 5. Getting Started

### Step 1: Run the Standalone Recognition Prototype
Test the OpenCV YuNet + SFace camera pipeline with consecutive-frame confirmation:
```bash
python desktop/prototype_recognition.py
```
* **Keys:**
  * `[E]`: Enroll a student interactively (captures 5 samples)
  * `[L]`: List enrolled students in local SQLite
  * `[R]`: Reset session buffer
  * `[Q]`: Quit

---

### Step 2: Run the Cloud Backend API
```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt

# Seed sample data (Prof. Alan Turing, CS-401, Alice, Bob, Charlie)
python seed_data.py

# Launch FastAPI
uvicorn app.main:app --reload --port 8000
```
* Interactive API Documentation: [http://localhost:8000/docs](http://localhost:8000/docs)
* Default Seeded Accounts:
  * **Teacher:** `teacher@school.edu` / `teacher123`
  * **Student:** `2024-CS-001` / `student123`

---

### Step 3: Run the Windows Desktop Application
```bash
cd desktop
pip install -r requirements.txt
python app/main.py
```
* **Tabs available:**
  * 📹 **Live Session:** Real-time webcam feed, face bounding boxes, name tags, live roster.
  * 👤 **Student Enrollment:** Capture and average 5 biometric samples locally.
  * 🏫 **Class Setup:** Start and conclude lecture attendance sessions.
  * 📊 **Records & Correction:** Review attendance logs and export to CSV.
  * 🔄 **Cloud Sync Status:** Upload queued records in batch to the FastAPI backend.

---

### Step 4: Run the Student Mobile App
```bash
cd mobile
flutter pub get
flutter run
```
* Sign in with Roll Number `2024-CS-001` and password `student123` to view real-time attendance percentages and historical lecture attendance.
