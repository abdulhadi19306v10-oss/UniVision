# 🎓 Focus: Privacy-Preserving Face Recognition Attendance System

[![Architecture](https://img.shields.io/badge/Architecture-Edge--Cloud%20Tri--Tier-indigo?style=for-the-badge)](focus.md)
[![Edge AI](https://img.shields.io/badge/Edge%20AI-OpenCV%20YuNet%20%2B%20SFace%20(ONNX)-green?style=for-the-badge)](desktop/)
[![Desktop UI](https://img.shields.io/badge/Desktop%20UI-Flutter%20Desktop%20%2B%20PySide6-cyan?style=for-the-badge)](desktop_flutter/)
[![Backend](https://img.shields.io/badge/Cloud%20API-FastAPI%20%2B%20PostgreSQL-teal?style=for-the-badge)](backend/)
[![Mobile](https://img.shields.io/badge/Mobile-Flutter-blue?style=for-the-badge)](mobile/)
[![Tests](https://img.shields.io/badge/Tests-100%25%20Passing-emerald?style=for-the-badge)](tests/)

---

## 📌 1. Overview & Core Philosophy

**Focus Attendance** is an automated, privacy-first facial recognition attendance system designed for educational institutions.

### 🛡️ Fundamental Design Principle
> **Biometric data never leaves the classroom PC.**  
> Face images and 128-dimensional embedding vectors are captured, stored, and matched **locally** inside an encrypted SQLite database on the Windows machine. The cloud backend **never** sees or stores biometric embeddings—it only receives minimal attendance records (`student_id`, `session_id`, `timestamp`, `method`, `confidence`).

```
[Camera] ──> [Windows Station: Detect (YuNet) + Embed (SFace) + Match (Local)]
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
    subgraph DesktopApp ["Desktop Workstation (Edge PC) — Hybrid MVC + EDA"]
        View_Flutter["Flutter Desktop Station / PySide6 GUI"]
        Bridge_Py["Python AI & Storage Bridge (REST + WS)"]
        Ctrl_Py["Controllers (Session, Enrollment, Sync)"]
        Model_Py[("Local SQLite Storage (Embeddings & Queue)")]
        Bus_Py(("DesktopEventBus (Qt Signals / WebSocket)"))
        Worker_Py["Camera & AI Worker (Dedicated Thread)"]

        View_Flutter <-->|REST & WebSocket| Bridge_Py
        Bridge_Py --> Ctrl_Py
        Ctrl_Py --> Worker_Py
        Worker_Py -->|Publish: frame_processed| Bus_Py
        Worker_Py -->|Publish: attendance_confirmed| Bus_Py
        Bus_Py --> Ctrl_Py
        Bus_Py --> View_Flutter
        Ctrl_Py -->|Persist Queue| Model_Py
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

    Ctrl_Py -->|HTTP POST /attendance/batch| Route_FastAPI
    Handler_Notify -.->|Real-Time Push Alerts (WS)| MobileApp["Student Mobile App (Flutter)"]
```

| Layer | Model | View | Controller | Event-Driven Mechanism |
|---|---|---|---|---|
| **Edge Desktop Station** | `LocalStorage` (SQLite) | `desktop_flutter` (Flutter Desktop) / `MainWindow` (PySide6) | `SessionController`, `SyncController`, `EnrollmentController` | `DesktopEventBus` + `CameraWorker` + WebSocket |
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
├── run_desktop_flutter.bat         # One-click launcher for Flutter Desktop + AI Bridge
├── run_dektop_flutter.bat          # Convenience alias launcher
├── run_dektop_flutter.app          # Shell/batch executable launcher
├── run_desktop.bat                 # PySide6 desktop launcher
│
├── desktop_flutter/                # Redesigned Flutter Desktop Workstation (Native Windows)
│   ├── pubspec.yaml                # Flutter desktop dependencies
│   ├── lib/
│   │   ├── main.dart               # Workstation entry point
│   │   ├── theme.dart              # Fluent Neumorphic dark theme
│   │   ├── services/
│   │   │   └── bridge_client.dart  # REST & WebSocket client to local Python AI engine
│   │   ├── widgets/
│   │   │   ├── sidebar.dart        # Station navigation & offline SQLite indicator
│   │   │   └── top_bar.dart        # Active session context & KPI chips (Present, FPS, Sync Queue)
│   │   └── screens/
│   │       ├── live_monitoring_screen.dart   # Camera HUD, quick session controls, live roster
│   │       ├── enrollment_screen.dart        # 5-sample biometric registration & directory
│   │       ├── attendance_logs_screen.dart   # Offline queue verification & CSV export
│   │       └── cloud_diagnostics_screen.dart # Cloud sync trigger & activity log terminal
│   └── test/
│       ├── bridge_client_test.dart # Unit tests for BridgeClient
│       └── widget_test.dart        # Integration & UI test suite
│
├── desktop/                        # Python Edge AI & Storage Engine
│   ├── prototype_recognition.py    # Step 1 Standalone Recognition Prototype
│   ├── requirements.txt            # Desktop dependencies (PySide6, OpenCV, ONNX, FastAPI)
│   ├── test_desktop_architecture.py# Desktop MVC + EventBus tests
│   ├── test_pipeline_and_storage.py# Biometric math, liveness, SQLite & bridge API tests
│   ├── models/                     # Downloaded ONNX Model weights
│   │   ├── face_detection_yunet_2023mar.onnx
│   │   └── face_recognition_sface_2021dec.onnx
│   └── app/
│       ├── main.py                 # PySide6 application launcher
│       ├── bridge_service.py       # REST + WebSocket bridge for Flutter desktop
│       ├── recognition/            # Detection, embedding, matching, tracking, liveness
│       ├── storage/                # Local SQLite storage & offline queue
│       ├── controllers/            # SessionController, EnrollmentController, SyncController
│       ├── events/                 # DesktopEventBus (Qt Signals)
│       └── workers/                # CameraWorker background inference thread
│
├── backend/                        # Cloud FastAPI Service
│   ├── requirements.txt            # Backend dependencies
│   ├── seed_data.py                # Database seeder (teachers, students, courses)
│   ├── test_eda.py                 # Backend Event-Driven Architecture test
│   ├── test_api_and_pipeline.py    # Comprehensive REST, JWT, sessions & batch tests
│   ├── .env.example                # Environment configuration
│   └── app/
│       ├── main.py                 # FastAPI entry point & CORS
│       ├── database.py             # Neon Postgres & dev SQLite engine
│       ├── models.py               # SQLAlchemy schema models
│       ├── schemas.py              # Pydantic v2 DTOs (ConfigDict)
│       ├── auth_utils.py           # Bcrypt & RFC 7519 compliant JWT management
│       ├── events/                 # AsyncEventBus & background subscriber loop
│       └── routers/                # Auth, Sessions, Attendance, Students
│
└── mobile/                         # Flutter Student Mobile App
    ├── pubspec.yaml                # Flutter dependencies
    └── lib/
        ├── main.dart               # Mobile entry point
        ├── models/                 # AttendanceModel, CourseSummary
        ├── services/               # HTTP client to FastAPI backend
        └── screens/                # Login & Dashboard screens
```

---

## 🚀 5. Getting Started

### Step 1: Run the Standalone Recognition Prototype
Test the OpenCV YuNet + SFace camera pipeline with consecutive-frame confirmation:
```bash
python desktop/prototype_recognition.py
```

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

### Step 3: Run the Flutter Desktop Workstation (Recommended)

Run the one-click launch script:
```powershell
.\run_desktop_flutter.bat
```
*(or run `.\run_dektop_flutter.bat` / `.\run_dektop_flutter.app`)*

This starts the Python AI & SQLite Bridge service on `http://127.0.0.1:8001` and launches the Flutter Windows desktop application.

Alternatively, execute the compiled release binary directly:
```powershell
.\desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe
```

---

### Step 4: Run the PySide6 Desktop Application (Alternative)
```bash
cd desktop
python app/main.py
```
*(or run `.\run_desktop.bat`)*

---

### Step 5: Run the Student Mobile App
```bash
cd mobile
flutter pub get
flutter run
```
* Sign in with Roll Number `2024-CS-001` and password `student123`.

---

## 🧪 6. Rigorous Automated Test Suites

### Python Backend & Desktop Test Suite (`pytest`)
Run from the workspace root:
```powershell
python -m pytest
```
- **14 passed** in ~4 seconds:
  - `backend/test_api_and_pipeline.py`: Auth, JWT, session permissions, idempotent batch uploads, student self-service.
  - `backend/test_eda.py`: EventBus publish/subscribe, async workers, and AuditLog persistence.
  - `desktop/test_desktop_architecture.py`: Desktop MVC, signal buffering, multi-face tracking.
  - `desktop/test_pipeline_and_storage.py`: Cosine similarity math, anti-spoof liveness variance, SQLite queue, bridge API.

### Flutter Desktop Test Suite (`flutter test`)
Run from `desktop_flutter`:
```powershell
cd desktop_flutter
flutter test
```
- **7 passed** in ~16 seconds:
  - `test/bridge_client_test.dart`: Session state, camera toggle, enrollment/deletion, simulation matching, cloud sync.
  - `test/widget_test.dart`: UI rendering, navigation across all 4 screens, user interactions.
