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

```mermaid
flowchart LR
    Cam["Webcam / Camera Feed"] -->|"Raw Video Stream"| Station["Edge Desktop Station (PC)<br/>• YuNet Face Detector (ONNX)<br/>• SFace 128-d Embedder (ONNX)<br/>• Local Cosine Matcher<br/>• Offline SQLite Storage"]
    Station -->|"Attendance Records Only<br/>(student_id, session_id, timestamp)"| API["Cloud FastAPI Gateway<br/>• JWT Authentication & RBAC<br/>• Async EventBus Pipeline"]
    API <-->|"SQLAlchemy ORM"| DB[("Neon PostgreSQL<br/>Master Cloud Ledger")]
    API <-->|"HTTPS REST & WebSockets<br/>(Real-Time Push Alerts)"| Mobile["Student Mobile App<br/>(Flutter iOS / Android)"]
```

---

## 🏗️ 2. System Architecture: Strict Hybrid (MVC + Event-Driven)

The system strictly adheres to a **Hybrid Architecture** combining **Model-View-Controller (MVC)** with an asynchronous **Event-Driven Architecture (EDA)** across both the **Edge Desktop Workstation** and the **Cloud Backend Platform**.

```mermaid
flowchart TD
    subgraph EdgeStation ["Desktop Workstation (Edge PC) — Hybrid MVC + EDA"]
        direction TB
        View_Flutter["Flutter Desktop Station GUI<br/>(Fluent Dark UI / 60 FPS Render)"]
        View_PySide["PySide6 Alternative GUI<br/>(Qt Signals & Native Windows)"]
        Bridge_Py["Python AI Bridge Service<br/>(FastAPI REST + WebSocket)"]

        Ctrl_Session["SessionController"]
        Ctrl_Enroll["EnrollmentController"]
        Ctrl_Sync["SyncController"]

        Worker_Cam["Camera & AI Worker Thread<br/>(YuNet Detection + SFace Embedder)"]
        Bus_Desktop["DesktopEventBus<br/>(Qt Signals & WS Pub/Sub)"]
        Model_Local[("Local SQLite Storage<br/>• Enrolled 128-d Embeddings<br/>• Offline Attendance Queue")]

        View_Flutter -->|"REST Configuration & Actions"| Bridge_Py
        Bridge_Py -->|"Live Frame Stream & Telemetry (WS)"| View_Flutter
        Bridge_Py --> Ctrl_Session
        Bridge_Py --> Ctrl_Enroll
        Bridge_Py --> Ctrl_Sync

        Ctrl_Session --> Worker_Cam
        Worker_Cam -->|"Publish: frame_processed"| Bus_Desktop
        Worker_Cam -->|"Publish: attendance_confirmed"| Bus_Desktop

        Bus_Desktop --> Ctrl_Session
        Bus_Desktop --> Bridge_Py
        Bus_Desktop --> View_PySide

        Ctrl_Enroll -->|"Save 128-d Centroid Embeddings"| Model_Local
        Ctrl_Session -->|"Buffer Offline Attendance Records"| Model_Local
        Ctrl_Sync -->|"Read Pending Records"| Model_Local
    end

    subgraph CloudPlatform ["Cloud Backend API — Hybrid MVC + EDA"]
        direction TB
        Router_FastAPI["FastAPI Routers (Controllers)<br/>/auth | /sessions | /attendance/batch"]
        Schema_Pydantic["Pydantic v2 DTOs (Views)<br/>Request Validation & Serialization"]

        Bus_Cloud["AsyncEventBus<br/>(asyncio.Queue Pub/Sub)"]

        Handler_Att["Attendance Handler<br/>(Database Ingestion)"]
        Handler_Audit["Audit Log Handler<br/>(Security Compliance)"]
        Handler_Notify["Notification Dispatcher<br/>(WebSocket Push)"]

        Model_Postgres[("Neon PostgreSQL<br/>• Students & Courses<br/>• Master Attendance Ledger<br/>• Immutable Audit Logs")]

        Router_FastAPI --> Schema_Pydantic
        Router_FastAPI -->|"Publish: BatchAttendanceReceived"| Bus_Cloud

        Bus_Cloud -->|"Dispatch Event"| Handler_Att
        Bus_Cloud -->|"Dispatch Event"| Handler_Audit
        Bus_Cloud -->|"Dispatch Event"| Handler_Notify

        Handler_Att -->|"ACID Commit"| Model_Postgres
        Handler_Audit -->|"Append Log"| Model_Postgres
    end

    subgraph MobileClient ["Student Mobile App (Flutter)"]
        View_Mobile["Flutter Screens<br/>(Login & Dashboard)"]
        Service_Mobile["ApiService & WS Client"]

        View_Mobile <--> Service_Mobile
    end

    %% Cross-Subsystem Interconnections
    Ctrl_Sync -->|"HTTPS POST /attendance/batch<br/>(Idempotent Offline Sync)"| Router_FastAPI
    Service_Mobile -->|"HTTPS GET /students/me/attendance<br/>(JWT Authenticated)"| Router_FastAPI
    Handler_Notify -.->|"WebSocket Real-Time Alert<br/>(Attendance Confirmed)"| Service_Mobile
```

| Layer | Model | View | Controller | Event-Driven Mechanism |
|---|---|---|---|---|
| **Edge Desktop Station** | `LocalStorage` (SQLite) | `desktop_flutter` (Flutter Desktop) / `MainWindow` (PySide6) | `SessionController`, `SyncController`, `EnrollmentController` | `DesktopEventBus` + `CameraWorker` + WebSocket |
| **Cloud Backend** | SQLAlchemy (`models.py`) | Pydantic DTOs (`schemas.py`) | FastAPI Routers (`routers/`) | `AsyncEventBus` (`asyncio.Queue`) + Handlers |
| **Mobile Client** | `attendance_model.dart` | Flutter Widgets (`screens/`) | `ApiService` | WebSocket Push Receiver (`/ws/student/{id}`) |

---

### 🏛️ Detailed Architectural Breakdown: How Both Subsystems Work

The system is split into two primary subsystems that operate synergistically while maintaining strict boundaries of privacy and operational independence.

#### 1. Edge Desktop Workstation Subsystem (Local Offline-First AI Engine)

The desktop workstation is designed for local edge execution on the classroom PC. It guarantees zero cloud biometric leakage and functions seamlessly even during network outages.

* **Model Layer (`desktop/app/storage/local_db.py`):**
  * Powered by a local SQLite database (`desktop_attendance.db`).
  * Stores student profiles, class rosters, and 128-dimensional biometric embeddings serialized as binary BLOBs.
  * Implements an offline attendance buffer table with sync state tracking (`sync_status = 'pending' | 'synced'`).
  * **Privacy Guarantee:** Facial images and embedding vectors are strictly confined to this local file and are **never** transmitted across the network.

* **View Layer (`desktop_flutter/` & `desktop/app/ui/`):**
  * **Flutter Desktop Workstation (Primary):** Built with Flutter Windows runner, offering a 60 FPS hardware-accelerated interface with fluent neumorphic styling. Features a dynamic Camera HUD with real-time bounding box overlays, 5-sample biometric enrollment wizard, offline attendance ledger, and cloud diagnostics terminal.
  * **PySide6 Native GUI (Alternative):** A Qt-based desktop UI providing native widgets, camera feeds, and direct Qt Signal slots.

* **Controller Layer (`desktop/app/controllers/`):**
  * **`SessionController`:** Manages lecture session lifecycles, active student rosters, duplicate-marking guards, and confidence threshold validations.
  * **`EnrollmentController`:** Drives multi-angle facial sample captures (center, left, right, up, down), calculates normalized centroid embeddings ($\mathbf{v}_{\text{profile}} = \frac{1}{K} \sum_{k=1}^K \mathbf{v}_k$), and persists them into local SQLite.
  * **`SyncController`:** Monitors internet connectivity, bundles buffered attendance records into atomic batches, sends idempotent sync payloads to the Cloud API, and marks records as `synced` upon HTTP 200 acknowledgment.

* **Event-Driven Architecture (EDA) & Local Bridge (`desktop/app/events/` & `bridge_service.py`):**
  * **`CameraWorker`:** A dedicated background thread decoupled from the UI. Captures frames at 30 FPS, runs OpenCV **YuNet** face detection, extracts 128-d vectors via **SFace**, computes Cosine Similarity against enrolled students, and evaluates spatial bounding-box variance for anti-spoofing.
  * **`DesktopEventBus`:** Publishes `frame_processed` and `attendance_confirmed` events to listening controllers.
  * **`BridgeService`:** An ASGI bridge exposing REST control endpoints and a high-speed WebSocket stream (`/ws/camera`) that transmits annotated JPEG frames and recognition telemetry directly to Flutter Desktop with near-zero latency.

---

#### 2. Cloud Backend Platform Subsystem (Asynchronous Event-Driven Cloud Server)

The cloud backend provides centralized data aggregation, institutional reporting, role-based access control, and real-time push alerting.

* **Model Layer (`backend/app/models.py`):**
  * Built using SQLAlchemy ORM connected to Neon Serverless PostgreSQL (with fallback to SQLite in development).
  * Defines entities: `User` (RBAC: Admin, Teacher, Student), `Student`, `Course`, `Session`, `AttendanceRecord` (immutable attendance ledger with composite unique constraints on `[student_id, session_id]`), and `AuditLog` (append-only compliance trail).
  * **Zero Biometrics:** Schema completely omits face embeddings or biometric matrices.

* **View Layer (`backend/app/schemas.py`):**
  * Strongly-typed Pydantic v2 schemas providing automatic data validation, RFC 7519 JWT payload definitions, and clean JSON serialization.

* **Controller Layer (`backend/app/routers/`):**
  * **`auth.py`:** Bcrypt password hashing, OAuth2 password bearer flow, and JWT token issuance and verification.
  * **`sessions.py`:** Academic course session scheduling, active status tracking, and history queries.
  * **`attendance.py`:** Handles batch attendance ingestion from edge workstations (`POST /attendance/batch`) and student attendance history lookups.
  * **`students.py`:** Student self-service profile queries and course attendance percentage calculations.

* **Event-Driven Architecture (EDA) & Asynchronous Handlers (`backend/app/events/`):**
  * **`AsyncEventBus`:** Powered by Python's `asyncio.Queue` and non-blocking background workers.
  * When an edge workstation uploads an attendance batch, the controller publishes a `BatchAttendanceReceived` event to the bus and immediately returns HTTP 200/201 in under 10 ms without waiting for database writes.
  * **Concurrent Handlers:**
    1. **`AttendanceHandler`:** Asynchronously writes records to PostgreSQL within an ACID transaction, validating enrollment and enforcing uniqueness.
    2. **`AuditHandler`:** Appends security audit entries with IP address, timestamp, device identifier, matching method (`facial_recognition`), and confidence score.
    3. **`NotificationHandler`:** Dispatches real-time WebSocket push notifications to connected student mobile applications on `/ws/student/{id}`, notifying students the moment they are marked present.

---

#### 3. End-to-End Operational Workflows

```mermaid
sequenceDiagram
    autonumber
    actor Student as Student
    actor Teacher as Teacher
    participant Cam as Classroom Camera
    participant Edge as Desktop Workstation (YuNet + SFace)
    participant LocalDB as SQLite (Local Encrypted)
    participant Cloud as FastAPI Backend (Async EDA)
    participant CloudDB as Neon PostgreSQL
    participant Mobile as Student Mobile App

    Note over Teacher,LocalDB: Phase 1: Biometric Enrollment (Local Only)
    Teacher->>Edge: Start Enrollment (Roll No, Name)
    Cam->>Edge: Capture 5 Facial Angles
    Edge->>Edge: YuNet Detect + SFace Embed (128-d)
    Edge->>Edge: Compute Centroid Vector
    Edge->>LocalDB: Store Biometric Profile (Local BLOB)

    Note over Student,Mobile: Phase 2: Live Recognition & Attendance Marking
    Teacher->>Edge: Start Session (CS-401)
    Student->>Cam: Walks in front of camera
    Cam->>Edge: 30 FPS Video Frames
    Edge->>Edge: Detect Face + Cosine Match (Score >= 0.50)
    Edge->>Edge: Confirm 3 Consecutive Matching Frames
    Edge->>LocalDB: Record Marked Present (sync_status = 'pending')
    Edge-->>Teacher: Live HUD Update (Green Box + Confirmed)

    Note over Edge,Mobile: Phase 3: Offline-First Sync & Real-Time Push Alert
    Edge->>Cloud: POST /attendance/batch (student_id, session_id, time)
    Cloud->>Cloud: AsyncEventBus.publish(BatchAttendanceReceived)
    Cloud-->>Edge: HTTP 200 OK (sync_status = 'synced')
    par Async Database Commit
        Cloud->>CloudDB: Insert AttendanceRecord & AuditLog
    and Async Real-Time Push
        Cloud-->>Mobile: WebSocket Push Notification ("Marked Present in CS-401")
        Mobile-->>Student: Display Real-Time Alert & Update Attendance %
    end
```

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

### Step 3: Run the Flutter Desktop Workstation (Production Ready)

Run the one-click launch script:
```powershell
.\run_desktop_flutter.bat
```
*(or run `.\run_dektop_flutter.bat` / `.\run_dektop_flutter.app`)*

This launches the Python AI & SQLite Bridge service on `http://127.0.0.1:8001` and opens the compiled Flutter Windows release binary (`desktop_flutter.exe`):
* **Live AI Camera Stream:** Real webcam streaming at 30 FPS with YuNet face detection boxes, SFace ArcFace cosine similarity scores, and verification status overlays.
* **Biometric Enrollment:** 5-angle camera capture averaging face feature vectors into offline SQLite storage (`desktop_attendance.db`).
* **Automated Session Roster:** 3-consecutive-frame temporal streak verification with auto-queuing into SQLite attendance records.
* **Manual Attendance Override:** Teacher manual attendance marking and record management with deletion support.
* **CSV Export:** Real CSV export to `desktop/exports/` for institutional reporting.
* **Cloud Sync:** Direct sync to FastAPI backend with connection diagnostics and live activity terminal.

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
- **8 passed** in ~16 seconds:
  - `test/bridge_client_test.dart`: Session state, camera toggle, enrollment/deletion, simulation matching, cloud sync.
  - `test/widget_test.dart`: Full UI rendering, responsive layout checks, navigation across all 4 workstation screens, manual override and sync actions.

