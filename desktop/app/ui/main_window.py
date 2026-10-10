import cv2
import numpy as np
from datetime import datetime
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QTabWidget,
    QLabel, QPushButton, QLineEdit, QTableWidget, QTableWidgetItem,
    QHeaderView, QMessageBox, QFileDialog, QProgressBar,
    QGroupBox, QFormLayout, QFrame
)
from PySide6.QtGui import QImage, QPixmap, QFont, QColor
from PySide6.QtCore import Qt, Slot

from ..events.event_bus import desktop_event_bus
from ..storage.local_db import LocalStorage
from ..storage.sync_client import CloudSyncClient
from ..workers.camera_worker import CameraWorker
from ..controllers.session_controller import SessionController
from ..controllers.sync_controller import SyncController
from ..controllers.enrollment_controller import EnrollmentController

class MainWindow(QMainWindow):
    """
    Pure MVC View Layer for the Edge Windows Desktop Application.
    Renders presentation widgets, captures user gestures, delegates commands to
    Controllers, and subscribes to thread-safe events emitted by DesktopEventBus.
    """
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Focus Face Recognition Attendance — Hybrid Architecture (MVC + EDA)")
        self.resize(1150, 750)

        # 1. Models & Storage
        self.storage = LocalStorage()
        self.sync_client = CloudSyncClient(local_storage=self.storage)

        # 2. Background Event Worker (QThread)
        self.camera_worker = CameraWorker(self.storage)

        # 3. MVC Controllers
        self.session_controller = SessionController(self.storage)
        self.sync_controller = SyncController(self.storage, self.sync_client)
        self.enrollment_controller = EnrollmentController(self.storage, self.camera_worker)

        self.setup_ui()
        self.subscribe_to_event_bus()

    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Header Banner
        header = QFrame()
        header.setFrameShape(QFrame.StyledPanel)
        header.setStyleSheet("background-color: #1e293b; color: white; padding: 10px; border-radius: 8px;")
        h_layout = QHBoxLayout(header)
        title_label = QLabel("🎓 Focus Classroom Biometrics Station (MVC + EDA)")
        title_label.setFont(QFont("Arial", 15, QFont.Bold))
        h_layout.addWidget(title_label)

        self.status_chip = QLabel("🟢 System Ready (Offline-First)")
        self.status_chip.setStyleSheet("background-color: #065f46; color: #a7f3d0; padding: 6px 12px; border-radius: 12px; font-weight: bold;")
        h_layout.addStretch()
        h_layout.addWidget(self.status_chip)
        main_layout.addWidget(header)

        # Tab Navigation
        self.tabs = QTabWidget()
        self.tabs.setFont(QFont("Arial", 11))

        self.tab_live = QWidget()
        self.tab_enroll = QWidget()
        self.tab_setup = QWidget()
        self.tab_records = QWidget()
        self.tab_sync = QWidget()

        self.tabs.addTab(self.tab_live, "📹 Live Session")
        self.tabs.addTab(self.tab_enroll, "👤 Student Enrollment")
        self.tabs.addTab(self.tab_setup, "🏫 Class Setup")
        self.tabs.addTab(self.tab_records, "📊 Records & Correction")
        self.tabs.addTab(self.tab_sync, "🔄 Cloud Sync Status")

        main_layout.addWidget(self.tabs)

        self.setup_live_tab()
        self.setup_enroll_tab()
        self.setup_class_tab()
        self.setup_records_tab()
        self.setup_sync_tab()

    # --- TAB 1: LIVE SESSION VIEW ---
    def setup_live_tab(self):
        layout = QHBoxLayout(self.tab_live)

        # Left: Video Feed Display
        left_box = QGroupBox("Camera Stream (Decoupled QThread Worker)")
        left_layout = QVBoxLayout(left_box)

        self.video_label = QLabel("Camera Offline. Click 'Start Camera Worker' below.")
        self.video_label.setAlignment(Qt.AlignCenter)
        self.video_label.setStyleSheet("background-color: #0f172a; color: #64748b; font-size: 14px; border-radius: 8px;")
        self.video_label.setMinimumSize(640, 480)
        left_layout.addWidget(self.video_label)

        btn_row = QHBoxLayout()
        self.btn_toggle_cam = QPushButton("Start Camera Worker")
        self.btn_toggle_cam.setStyleSheet("background-color: #0284c7; color: white; padding: 10px; font-weight: bold;")
        self.btn_toggle_cam.clicked.connect(self.on_toggle_camera_clicked)
        btn_row.addWidget(self.btn_toggle_cam)
        left_layout.addLayout(btn_row)

        layout.addWidget(left_box, 3)

        # Right: Live Present Roster View
        right_box = QGroupBox("Session Roster (Event-Driven Live Update)")
        right_layout = QVBoxLayout(right_box)

        self.session_info_label = QLabel("No active session. Please start a session in 'Class Setup'.")
        self.session_info_label.setWordWrap(True)
        self.session_info_label.setStyleSheet("color: #475569; font-style: italic; margin-bottom: 8px;")
        right_layout.addWidget(self.session_info_label)

        self.table_present = QTableWidget(0, 3)
        self.table_present.setHorizontalHeaderLabels(["Roll No", "Full Name", "Time"])
        self.table_present.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        right_layout.addWidget(self.table_present)

        layout.addWidget(right_box, 2)

    # --- TAB 2: ENROLLMENT VIEW ---
    def setup_enroll_tab(self):
        layout = QVBoxLayout(self.tab_enroll)
        form_box = QGroupBox("Enroll Student Face Biometrics (Local Storage Only)")
        form_layout = QFormLayout(form_box)

        self.inp_student_id = QLineEdit()
        self.inp_student_id.setPlaceholderText("e.g. 1")
        form_layout.addRow("Cloud Student ID:", self.inp_student_id)

        self.inp_roll = QLineEdit()
        self.inp_roll.setPlaceholderText("e.g. 2024-CS-001")
        form_layout.addRow("Roll Number:", self.inp_roll)

        self.inp_name = QLineEdit()
        self.inp_name.setPlaceholderText("e.g. Alice Johnson")
        form_layout.addRow("Full Name:", self.inp_name)

        self.btn_start_enroll = QPushButton("Capture Biometrics & Enroll (5 Samples)")
        self.btn_start_enroll.setStyleSheet("background-color: #10b981; color: white; padding: 12px; font-weight: bold;")
        self.btn_start_enroll.clicked.connect(self.on_start_enroll_clicked)
        form_layout.addRow(self.btn_start_enroll)

        layout.addWidget(form_box)

        # Enrolled Students Table
        enrolled_box = QGroupBox("Enrolled Students on this Machine")
        enrolled_layout = QVBoxLayout(enrolled_box)
        self.table_enrolled = QTableWidget(0, 3)
        self.table_enrolled.setHorizontalHeaderLabels(["Student ID", "Roll Number", "Full Name"])
        self.table_enrolled.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        enrolled_layout.addWidget(self.table_enrolled)
        layout.addWidget(enrolled_box)

        self.refresh_enrolled_table()

    # --- TAB 3: CLASS SETUP VIEW ---
    def setup_class_tab(self):
        layout = QVBoxLayout(self.tab_setup)
        box = QGroupBox("Lecture Session Controls")
        form = QFormLayout(box)

        self.inp_course_id = QLineEdit("1")
        form.addRow("Course ID:", self.inp_course_id)

        self.inp_course_code = QLineEdit("CS-401")
        form.addRow("Course Code:", self.inp_course_code)

        self.inp_course_name = QLineEdit("Software Design & Architecture")
        form.addRow("Course Name:", self.inp_course_name)

        self.btn_session_control = QPushButton("Start Lecture Session")
        self.btn_session_control.setStyleSheet("background-color: #2563eb; color: white; padding: 12px; font-weight: bold;")
        self.btn_session_control.clicked.connect(self.on_toggle_session_clicked)
        form.addRow(self.btn_session_control)

        layout.addWidget(box)
        layout.addStretch()

    # --- TAB 4: RECORDS VIEW ---
    def setup_records_tab(self):
        layout = QVBoxLayout(self.tab_records)
        top_bar = QHBoxLayout()

        btn_refresh = QPushButton("Refresh Records")
        btn_refresh.clicked.connect(self.refresh_records_table)
        top_bar.addWidget(btn_refresh)

        btn_export = QPushButton("Export to CSV")
        btn_export.clicked.connect(self.on_export_csv_clicked)
        top_bar.addWidget(btn_export)

        top_bar.addStretch()
        layout.addLayout(top_bar)

        self.table_records = QTableWidget(0, 7)
        self.table_records.setHorizontalHeaderLabels(["ID", "Roll No", "Name", "Marked Time", "Method", "Confidence", "Sync Status"])
        self.table_records.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.table_records)

    # --- TAB 5: SYNC STATUS VIEW ---
    def setup_sync_tab(self):
        layout = QVBoxLayout(self.tab_sync)
        box = QGroupBox("Cloud Synchronization (FastAPI + Neon Postgres)")
        form = QFormLayout(box)

        self.inp_backend_url = QLineEdit("http://localhost:8000")
        form.addRow("Backend API URL:", self.inp_backend_url)

        self.inp_teacher_email = QLineEdit("teacher@school.edu")
        form.addRow("Teacher Email:", self.inp_teacher_email)

        self.inp_teacher_pwd = QLineEdit("teacher123")
        self.inp_teacher_pwd.setEchoMode(QLineEdit.Password)
        form.addRow("Teacher Password:", self.inp_teacher_pwd)

        self.btn_sync_now = QPushButton("Sync Queued Records to Cloud Now")
        self.btn_sync_now.setStyleSheet("background-color: #059669; color: white; padding: 12px; font-weight: bold;")
        self.btn_sync_now.clicked.connect(self.on_sync_now_clicked)
        form.addRow(self.btn_sync_now)

        layout.addWidget(box)

        self.sync_log = QLabel("Sync Log: No sync performed yet.")
        self.sync_log.setStyleSheet("background-color: #f1f5f9; padding: 10px; border-radius: 6px;")
        layout.addWidget(self.sync_log)
        layout.addStretch()

    # --- EVENT BUS SUBSCRIPTIONS (EDA LAYER) ---
    def subscribe_to_event_bus(self):
        # 1. Listen to camera frame events for display
        desktop_event_bus.frame_processed.connect(self.on_frame_processed)

        # 2. Listen to attendance queued events for real-time roster update
        desktop_event_bus.record_queued.connect(self.on_attendance_record_queued)

        # 3. Listen to session lifecycle events
        desktop_event_bus.session_started.connect(self.on_session_started_event)
        desktop_event_bus.session_ended.connect(self.on_session_ended_event)

        # 4. Listen to sync status events
        desktop_event_bus.sync_status_changed.connect(self.on_sync_status_changed_event)

    @Slot(object, list, float)
    def on_frame_processed(self, display_frame: np.ndarray, detected_faces: list, fps: float):
        """Thread-safe UI slot displaying the processed video frame from CameraWorker."""
        rgb_image = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
        h, w, ch = rgb_image.shape
        bytes_per_line = ch * w
        q_img = QImage(rgb_image.data, w, h, bytes_per_line, QImage.Format_RGB888)
        pix = QPixmap.fromImage(q_img)
        self.video_label.setPixmap(pix.scaled(self.video_label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))

    @Slot(dict)
    def on_attendance_record_queued(self, record: dict):
        """Thread-safe UI slot triggered when a new attendance record is confirmed and queued."""
        row = self.table_present.rowCount()
        self.table_present.insertRow(row)
        self.table_present.setItem(row, 0, QTableWidgetItem(record.get("roll_no", "")))
        self.table_present.setItem(row, 1, QTableWidgetItem(record.get("full_name", "")))
        self.table_present.setItem(row, 2, QTableWidgetItem(record.get("time", "")))

    @Slot(int, str, str)
    def on_session_started_event(self, local_id: int, course_code: str, course_name: str):
        self.session_info_label.setText(f"Active Session: {course_code} - {course_name} (ID: #{local_id})")
        self.status_chip.setText(f"🟢 Active Session: {course_code}")
        self.btn_session_control.setText("End Lecture Session")
        self.btn_session_control.setStyleSheet("background-color: #dc2626; color: white; padding: 12px; font-weight: bold;")
        self.table_present.setRowCount(0)

    @Slot(int)
    def on_session_ended_event(self, local_id: int):
        self.session_info_label.setText("No active session. Please start a session in 'Class Setup'.")
        self.status_chip.setText("🟢 System Ready (Offline-First)")
        self.btn_session_control.setText("Start Lecture Session")
        self.btn_session_control.setStyleSheet("background-color: #2563eb; color: white; padding: 12px; font-weight: bold;")
        self.refresh_records_table()

    @Slot(str, dict)
    def on_sync_status_changed_event(self, message: str, stats: dict):
        self.sync_log.setText(message)
        if stats.get("action") == "ENROLLMENT_COMPLETED":
            self.refresh_enrolled_table()
            QMessageBox.information(self, "Biometric Enrollment Success", message)

    # --- CONTROLLER DELEGATION (USER ACTIONS) ---
    def on_toggle_camera_clicked(self):
        if not self.camera_worker.isRunning():
            self.camera_worker.start()
            self.btn_toggle_cam.setText("Stop Camera Worker")
            self.btn_toggle_cam.setStyleSheet("background-color: #dc2626; color: white; padding: 10px; font-weight: bold;")
        else:
            self.camera_worker.stop_worker()
            self.video_label.setText("Camera Worker Stopped.")
            self.btn_toggle_cam.setText("Start Camera Worker")
            self.btn_toggle_cam.setStyleSheet("background-color: #0284c7; color: white; padding: 10px; font-weight: bold;")

    def on_toggle_session_clicked(self):
        if self.session_controller.active_local_session_id is None:
            try:
                cid = int(self.inp_course_id.text().strip())
                ccode = self.inp_course_code.text().strip()
                cname = self.inp_course_name.text().strip()
            except ValueError:
                QMessageBox.warning(self, "Input Error", "Please provide a valid Course ID.")
                return

            self.session_controller.start_session(cid, ccode, cname)
            if not self.camera_worker.isRunning():
                self.on_toggle_camera_clicked()
            self.tabs.setCurrentIndex(0)
        else:
            sid = self.session_controller.end_session()
            QMessageBox.information(self, "Session Ended", f"Lecture session #{sid} has concluded.")

    def on_start_enroll_clicked(self):
        try:
            sid = int(self.inp_student_id.text().strip())
            roll = self.inp_roll.text().strip()
            name = self.inp_name.text().strip()
            if not roll or not name:
                raise ValueError()
        except ValueError:
            QMessageBox.warning(self, "Input Error", "Please provide valid Student ID, Roll No, and Name.")
            return

        self.enrollment_controller.request_enrollment(sid, roll, name)
        self.tabs.setCurrentIndex(0)

    def on_sync_now_clicked(self):
        url = self.inp_backend_url.text().strip()
        email = self.inp_teacher_email.text().strip()
        pwd = self.inp_teacher_pwd.text().strip()
        self.sync_controller.sync_to_cloud(url, email, pwd)
        self.refresh_records_table()

    def on_export_csv_clicked(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export Attendance CSV", "attendance_export.csv", "CSV Files (*.csv)")
        if path:
            latest_id = self.session_controller.active_local_session_id or 1
            if self.storage.export_session_to_csv(latest_id, path):
                QMessageBox.information(self, "Export Successful", f"Saved records to {path}")
            else:
                QMessageBox.warning(self, "Export Failed", "No records found to export.")

    def refresh_enrolled_table(self):
        students = self.storage.list_enrolled_students()
        self.table_enrolled.setRowCount(0)
        for s in students:
            row = self.table_enrolled.rowCount()
            self.table_enrolled.insertRow(row)
            self.table_enrolled.setItem(row, 0, QTableWidgetItem(str(s["student_id"])))
            self.table_enrolled.setItem(row, 1, QTableWidgetItem(s["roll_no"]))
            self.table_enrolled.setItem(row, 2, QTableWidgetItem(s["full_name"]))

    def refresh_records_table(self):
        records = self.storage.get_pending_sync_records()
        self.table_records.setRowCount(0)
        for r in records:
            row = self.table_records.rowCount()
            self.table_records.insertRow(row)
            self.table_records.setItem(row, 0, QTableWidgetItem(str(r["id"])))
            self.table_records.setItem(row, 1, QTableWidgetItem(r["roll_no"]))
            self.table_records.setItem(row, 2, QTableWidgetItem(r["full_name"]))
            self.table_records.setItem(row, 3, QTableWidgetItem(r["marked_at"]))
            self.table_records.setItem(row, 4, QTableWidgetItem(r["method"]))
            self.table_records.setItem(row, 5, QTableWidgetItem(f"{r['confidence']:.2f}" if r["confidence"] else "N/A"))
            status_item = QTableWidgetItem("QUEUED" if r["synced"] == 0 else "SYNCED")
            status_item.setForeground(QColor("#f59e0b" if r["synced"] == 0 else "#10b981"))
            self.table_records.setItem(row, 6, status_item)

    def closeEvent(self, event):
        if self.camera_worker.isRunning():
            self.camera_worker.stop_worker()
        event.accept()
