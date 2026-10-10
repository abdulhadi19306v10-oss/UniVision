import os
import cv2
import time
import logging
import numpy as np
from datetime import datetime
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QStackedWidget,
    QLabel, QPushButton, QLineEdit, QTableWidget, QTableWidgetItem,
    QHeaderView, QMessageBox, QFileDialog, QProgressBar,
    QFrame, QGridLayout, QSplitter, QTextEdit, QComboBox
)
from PySide6.QtGui import QImage, QPixmap, QFont, QColor
from PySide6.QtCore import Qt, Slot, QTimer, QSize

from .theme import NEUMORPHIC_DARK_QSS
from .icons import create_vector_icon
from ..events.event_bus import desktop_event_bus
from ..storage.local_db import LocalStorage
from ..storage.sync_client import CloudSyncClient
from ..workers.camera_worker import CameraWorker
from ..controllers.session_controller import SessionController
from ..controllers.sync_controller import SyncController
from ..controllers.enrollment_controller import EnrollmentController

logger = logging.getLogger("MainWindow")

class MainWindow(QMainWindow):
    """
    Modern Neumorphic Dark UI for UniVision / Focus Attendance.
    Implements a clean MVC View Layer communicating with Domain Controllers
    and background workers purely through Qt Signals (Event-Driven Architecture).
    Professional typography and crisp vector iconography throughout.
    """
    def __init__(self):
        super().__init__()
        self.setWindowTitle("UniVision — Biometric Classroom Station (MVC + EDA)")
        self.resize(1280, 840)
        self.setMinimumSize(1080, 720)

        # Apply Global Neumorphic Stylesheet
        self.setStyleSheet(NEUMORPHIC_DARK_QSS)

        # 1. Models & Storage (M)
        self.storage = LocalStorage()
        self.sync_client = CloudSyncClient(local_storage=self.storage)

        # 2. Background Event Worker (EDA)
        self.camera_worker = CameraWorker(self.storage)

        # 3. Domain Controllers (C)
        self.session_controller = SessionController(self.storage)
        self.sync_controller = SyncController(self.storage, self.sync_client)
        self.enrollment_controller = EnrollmentController(self.storage, self.camera_worker)

        # Session tracking state
        self.session_start_time = None
        self.session_timer = QTimer(self)
        self.session_timer.timeout.connect(self.update_session_elapsed_time)

        # Flash effect state
        self.flash_timer = QTimer(self)
        self.flash_timer.setSingleShot(True)
        self.flash_timer.timeout.connect(self.clear_camera_flash)

        # Setup UI Components
        self.setup_ui()
        self.subscribe_to_event_bus()

        # Initial data load
        self.refresh_records_table()
        self.refresh_enrolled_table()
        self.update_sync_badge_count()

    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        root_layout = QHBoxLayout(central_widget)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        # 1. Left Navigation Sidebar
        sidebar = self.build_sidebar()
        root_layout.addWidget(sidebar)

        # 2. Right Stacked View Area
        content_container = QWidget()
        content_layout = QVBoxLayout(content_container)
        content_layout.setContentsMargins(20, 20, 20, 20)
        content_layout.setSpacing(16)

        # Top App Bar
        top_bar = self.build_top_bar()
        content_layout.addWidget(top_bar)

        # Main Stacked Pages
        self.stacked_pages = QStackedWidget()
        self.page_live = self.build_live_page()
        self.page_enroll = self.build_enroll_page()
        self.page_records = self.build_records_page()
        self.page_sync = self.build_sync_page()

        self.stacked_pages.addWidget(self.page_live)
        self.stacked_pages.addWidget(self.page_enroll)
        self.stacked_pages.addWidget(self.page_records)
        self.stacked_pages.addWidget(self.page_sync)

        content_layout.addWidget(self.stacked_pages)
        root_layout.addWidget(content_container, 1)

    # =========================================================================
    # SIDEBAR NAVIGATION
    # =========================================================================
    def build_sidebar(self) -> QWidget:
        sidebar = QFrame()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(240)
        layout = QVBoxLayout(sidebar)
        layout.setContentsMargins(12, 24, 12, 20)
        layout.setSpacing(8)

        # Logo & App Title
        logo_box = QFrame()
        logo_layout = QVBoxLayout(logo_box)
        logo_layout.setContentsMargins(8, 0, 8, 16)
        logo_layout.setSpacing(4)

        app_title = QLabel("UNIVISION")
        app_title.setFont(QFont("Segoe UI", 18, QFont.Bold))
        app_title.setStyleSheet("color: #38bdf8; letter-spacing: 2px;")

        app_subtitle = QLabel("Biometric Station")
        app_subtitle.setFont(QFont("Segoe UI", 10))
        app_subtitle.setStyleSheet("color: #94a3b8; font-weight: 500;")

        logo_layout.addWidget(app_title)
        logo_layout.addWidget(app_subtitle)
        layout.addWidget(logo_box)

        # Navigation Buttons with crisp Vector Icons
        self.nav_buttons = []
        nav_items = [
            ("video", "Live Monitoring", 0),
            ("user", "Biometrics Enroll", 1),
            ("logs", "Attendance Logs", 2),
            ("cloud", "Cloud & Diagnostics", 3)
        ]

        for icon_name, text, index in nav_items:
            btn = QPushButton(f"  {text}")
            btn.setIcon(create_vector_icon(icon_name, "#94a3b8", 18))
            btn.setIconSize(QSize(18, 18))
            btn.setProperty("class", "nav-btn")
            btn.setCheckable(True)
            btn.clicked.connect(lambda checked=False, idx=index: self.switch_page(idx))
            layout.addWidget(btn)
            self.nav_buttons.append((btn, icon_name))

        self.nav_buttons[0][0].setChecked(True)
        self.nav_buttons[0][0].setProperty("active", "true")
        self.nav_buttons[0][0].setIcon(create_vector_icon("video", "#38bdf8", 18))

        layout.addStretch()

        # Offline Engine Status Card in Sidebar
        offline_card = QFrame()
        offline_card.setProperty("class", "neumorphic-card")
        offline_layout = QVBoxLayout(offline_card)
        offline_layout.setContentsMargins(14, 12, 14, 12)
        offline_layout.setSpacing(4)

        offline_title = QLabel("LOCAL STORAGE")
        offline_title.setStyleSheet("color: #64748b; font-size: 10px; font-weight: bold; letter-spacing: 1px;")
        self.lbl_storage_status = QLabel("SQLite Offline-First")
        self.lbl_storage_status.setStyleSheet("color: #34d399; font-weight: bold; font-size: 11px;")

        offline_layout.addWidget(offline_title)
        offline_layout.addWidget(self.lbl_storage_status)
        layout.addWidget(offline_card)

        return sidebar

    def switch_page(self, page_index: int):
        self.stacked_pages.setCurrentIndex(page_index)
        for i, (btn, icon_name) in enumerate(self.nav_buttons):
            is_active = (i == page_index)
            btn.setChecked(is_active)
            btn.setProperty("active", "true" if is_active else "false")
            color = "#38bdf8" if is_active else "#94a3b8"
            btn.setIcon(create_vector_icon(icon_name, color, 18))
            btn.style().unpolish(btn)
            btn.style().polish(btn)

        if page_index == 2:
            self.refresh_records_table()
        elif page_index == 1:
            self.refresh_enrolled_table()
        elif page_index == 3:
            self.refresh_diagnostic_log()

    # =========================================================================
    # TOP HEADER & KPI METRICS BAR
    # =========================================================================
    def build_top_bar(self) -> QWidget:
        top_bar = QFrame()
        top_bar.setProperty("class", "neumorphic-card")
        layout = QHBoxLayout(top_bar)
        layout.setContentsMargins(16, 10, 16, 10)
        layout.setSpacing(16)

        # Left: Session Context Label
        self.lbl_active_header = QLabel("No active lecture session. Configure course and start session below.")
        self.lbl_active_header.setFont(QFont("Segoe UI", 12, QFont.DemiBold))
        self.lbl_active_header.setStyleSheet("color: #cbd5e1;")
        layout.addWidget(self.lbl_active_header)

        layout.addStretch()

        # KPI 1: Live Present Counter
        kpi_present = QFrame()
        kpi_present.setProperty("class", "kpi-card")
        kpi_p_lay = QHBoxLayout(kpi_present)
        kpi_p_lay.setContentsMargins(12, 6, 12, 6)
        self.lbl_kpi_present = QLabel("PRESENT: 0")
        self.lbl_kpi_present.setStyleSheet("color: #38bdf8; font-weight: bold; font-size: 12px; letter-spacing: 0.5px;")
        kpi_p_lay.addWidget(self.lbl_kpi_present)
        layout.addWidget(kpi_present)

        # KPI 2: Live Inference FPS Counter
        kpi_fps = QFrame()
        kpi_fps.setProperty("class", "kpi-card")
        kpi_f_lay = QHBoxLayout(kpi_fps)
        kpi_f_lay.setContentsMargins(12, 6, 12, 6)
        self.lbl_kpi_fps = QLabel("FPS: 0.0")
        self.lbl_kpi_fps.setStyleSheet("color: #34d399; font-weight: bold; font-size: 12px; letter-spacing: 0.5px;")
        kpi_f_lay.addWidget(self.lbl_kpi_fps)
        layout.addWidget(kpi_fps)

        # KPI 3: Sync Pending Queue Counter
        kpi_sync = QFrame()
        kpi_sync.setProperty("class", "kpi-card")
        kpi_s_lay = QHBoxLayout(kpi_sync)
        kpi_s_lay.setContentsMargins(12, 6, 12, 6)
        self.lbl_kpi_sync = QLabel("SYNC QUEUE: 0")
        self.lbl_kpi_sync.setStyleSheet("color: #fbbf24; font-weight: bold; font-size: 12px; letter-spacing: 0.5px;")
        kpi_s_lay.addWidget(self.lbl_kpi_sync)
        layout.addWidget(kpi_sync)

        return top_bar

    # =========================================================================
    # PAGE 0: LIVE SESSION (INTEGRATED CONTROLS + VIDEO HUD + ROSTER)
    # =========================================================================
    def build_live_page(self) -> QWidget:
        page = QWidget()
        page_layout = QVBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        page_layout.setSpacing(14)

        # 1. Integrated Quick Session Bar (Neumorphic Card)
        session_bar = QFrame()
        session_bar.setProperty("class", "neumorphic-card")
        bar_layout = QHBoxLayout(session_bar)
        bar_layout.setContentsMargins(14, 10, 14, 10)
        bar_layout.setSpacing(12)

        lbl_course = QLabel("Course Code:")
        lbl_course.setStyleSheet("color: #94a3b8; font-weight: bold;")
        bar_layout.addWidget(lbl_course)

        self.inp_quick_course_code = QLineEdit("CS-401")
        self.inp_quick_course_code.setFixedWidth(100)
        self.inp_quick_course_code.setPlaceholderText("Code")
        bar_layout.addWidget(self.inp_quick_course_code)

        lbl_name = QLabel("Name:")
        lbl_name.setStyleSheet("color: #94a3b8; font-weight: bold;")
        bar_layout.addWidget(lbl_name)

        self.inp_quick_course_name = QLineEdit("Software Architecture")
        self.inp_quick_course_name.setPlaceholderText("Course Name")
        bar_layout.addWidget(self.inp_quick_course_name)

        self.inp_quick_course_id = QLineEdit("101")
        self.inp_quick_course_id.setFixedWidth(50)
        self.inp_quick_course_id.setPlaceholderText("ID")
        bar_layout.addWidget(self.inp_quick_course_id)

        # Primary Start / End Session Toggle Button
        self.btn_session_toggle = QPushButton("  Start Lecture Session")
        self.btn_session_toggle.setIcon(create_vector_icon("play", "#ffffff", 14))
        self.btn_session_toggle.setProperty("class", "btn-success")
        self.btn_session_toggle.clicked.connect(self.on_session_toggle_clicked)
        bar_layout.addWidget(self.btn_session_toggle)

        # Session Duration Timer Badge
        self.lbl_session_elapsed = QLabel("TIME: 00:00:00")
        self.lbl_session_elapsed.setStyleSheet("color: #64748b; font-weight: bold; font-size: 12px; letter-spacing: 0.5px;")
        bar_layout.addWidget(self.lbl_session_elapsed)

        page_layout.addWidget(session_bar)

        # 2. Main Area Split: Video HUD (Left) vs Live Roster (Right)
        body_layout = QHBoxLayout()
        body_layout.setSpacing(14)

        # --- LEFT: Video HUD Stream ---
        left_box = QFrame()
        left_box.setProperty("class", "neumorphic-card")
        left_layout = QVBoxLayout(left_box)
        left_layout.setContentsMargins(14, 14, 14, 14)
        left_layout.setSpacing(10)

        # Video HUD sunken container
        self.video_container = QFrame()
        self.video_container.setProperty("class", "neumorphic-sunken")
        vc_layout = QVBoxLayout(self.video_container)
        vc_layout.setContentsMargins(6, 6, 6, 6)

        self.video_label = QLabel("Camera is inactive.\nClick 'Start Camera Stream' below to begin AI recognition.")
        self.video_label.setAlignment(Qt.AlignCenter)
        self.video_label.setStyleSheet("color: #64748b; font-size: 14px; background: transparent;")
        self.video_label.setMinimumSize(560, 420)
        vc_layout.addWidget(self.video_label)
        left_layout.addWidget(self.video_container, 1)

        # Recent Confirmation Toast
        self.lbl_confirmed_banner = QLabel("Biometrics Engine Ready • Waiting for faces...")
        self.lbl_confirmed_banner.setStyleSheet("color: #94a3b8; font-style: italic; padding: 2px 4px;")
        left_layout.addWidget(self.lbl_confirmed_banner)

        # Camera control bottom bar
        cam_bar = QHBoxLayout()
        self.btn_toggle_cam = QPushButton("  Start Camera Stream")
        self.btn_toggle_cam.setIcon(create_vector_icon("video", "#ffffff", 14))
        self.btn_toggle_cam.setProperty("class", "btn-primary")
        self.btn_toggle_cam.clicked.connect(self.on_toggle_camera_clicked)
        cam_bar.addWidget(self.btn_toggle_cam)

        cam_bar.addStretch()

        lbl_cam_idx = QLabel("Device:")
        lbl_cam_idx.setStyleSheet("color: #94a3b8;")
        cam_bar.addWidget(lbl_cam_idx)

        self.cb_camera_idx = QComboBox()
        self.cb_camera_idx.addItems(["Camera 0 (Default)", "Camera 1 (External)"])
        cam_bar.addWidget(self.cb_camera_idx)

        left_layout.addLayout(cam_bar)
        body_layout.addWidget(left_box, 3)

        # --- RIGHT: Live Attendance Roster & Manual Check-in ---
        right_box = QFrame()
        right_box.setProperty("class", "neumorphic-card")
        right_layout = QVBoxLayout(right_box)
        right_layout.setContentsMargins(14, 14, 14, 14)
        right_layout.setSpacing(10)

        roster_header = QHBoxLayout()
        lbl_roster_title = QLabel("Live Session Roster")
        lbl_roster_title.setFont(QFont("Segoe UI", 12, QFont.Bold))
        roster_header.addWidget(lbl_roster_title)
        roster_header.addStretch()

        self.inp_roster_search = QLineEdit()
        self.inp_roster_search.setPlaceholderText("Filter roll/name...")
        self.inp_roster_search.setFixedWidth(140)
        self.inp_roster_search.textChanged.connect(self.filter_live_roster)
        roster_header.addWidget(self.inp_roster_search)
        right_layout.addLayout(roster_header)

        # Present Students Table (Sunken Neumorphism)
        self.table_present = QTableWidget(0, 4)
        self.table_present.setHorizontalHeaderLabels(["Roll No", "Full Name", "Time", "Confidence"])
        self.table_present.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table_present.verticalHeader().setVisible(False)
        right_layout.addWidget(self.table_present, 1)

        # Quick Manual Attendance Check-in Bar
        manual_box = QFrame()
        manual_box.setProperty("class", "neumorphic-sunken")
        m_lay = QHBoxLayout(manual_box)
        m_lay.setContentsMargins(8, 8, 8, 8)
        m_lay.setSpacing(8)

        self.inp_manual_roll = QLineEdit()
        self.inp_manual_roll.setPlaceholderText("Manual Roll No...")
        m_lay.addWidget(self.inp_manual_roll)

        self.inp_manual_name = QLineEdit()
        self.inp_manual_name.setPlaceholderText("Student Name...")
        m_lay.addWidget(self.inp_manual_name)

        btn_manual_mark = QPushButton("  Check In")
        btn_manual_mark.setIcon(create_vector_icon("plus", "#ffffff", 14))
        btn_manual_mark.setProperty("class", "btn-primary")
        btn_manual_mark.clicked.connect(self.on_manual_checkin_clicked)
        m_lay.addWidget(btn_manual_mark)

        right_layout.addWidget(manual_box)
        body_layout.addWidget(right_box, 2)

        page_layout.addLayout(body_layout)
        return page

    # =========================================================================
    # PAGE 1: BIOMETRICS ENROLLMENT
    # =========================================================================
    def build_enroll_page(self) -> QWidget:
        page = QWidget()
        page_layout = QHBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        page_layout.setSpacing(14)

        # Form Card (Left)
        form_card = QFrame()
        form_card.setProperty("class", "neumorphic-card")
        f_layout = QVBoxLayout(form_card)
        f_layout.setContentsMargins(20, 20, 20, 20)
        f_layout.setSpacing(12)

        title = QLabel("Student Biometric Registration")
        title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        title.setStyleSheet("color: #38bdf8;")
        f_layout.addWidget(title)

        desc = QLabel(
            "Captures 5 face angles to generate a 128-d biometric embedding.\n"
            "Data is stored strictly in encrypted local SQLite on this PC."
        )
        desc.setStyleSheet("color: #94a3b8; line-height: 1.4;")
        f_layout.addWidget(desc)

        f_layout.addSpacing(6)

        f_layout.addWidget(QLabel("Cloud Student ID:"))
        self.inp_enroll_id = QLineEdit()
        self.inp_enroll_id.setPlaceholderText("e.g. 10")
        f_layout.addWidget(self.inp_enroll_id)

        f_layout.addWidget(QLabel("Student Roll Number:"))
        self.inp_enroll_roll = QLineEdit()
        self.inp_enroll_roll.setPlaceholderText("e.g. 2024-CS-010")
        f_layout.addWidget(self.inp_enroll_roll)

        f_layout.addWidget(QLabel("Full Name:"))
        self.inp_enroll_name = QLineEdit()
        self.inp_enroll_name.setPlaceholderText("e.g. Sarah Connor")
        f_layout.addWidget(self.inp_enroll_name)

        # Quick QoL Prefill & Reset Bar
        qol_row = QHBoxLayout()
        btn_prefill = QPushButton("Prefill Test Student")
        btn_prefill.clicked.connect(self.on_prefill_sample_student_clicked)
        qol_row.addWidget(btn_prefill)

        btn_clear = QPushButton("Clear Form")
        btn_clear.clicked.connect(self.on_clear_enroll_form_clicked)
        qol_row.addWidget(btn_clear)
        f_layout.addLayout(qol_row)

        f_layout.addSpacing(6)

        self.btn_start_enroll = QPushButton("  Start Biometric Capture (5 Samples)")
        self.btn_start_enroll.setIcon(create_vector_icon("user", "#ffffff", 14))
        self.btn_start_enroll.setProperty("class", "btn-success")
        self.btn_start_enroll.clicked.connect(self.on_start_enroll_clicked)
        f_layout.addWidget(self.btn_start_enroll)

        self.enroll_progress = QProgressBar()
        self.enroll_progress.setRange(0, 5)
        self.enroll_progress.setValue(0)
        self.enroll_progress.setStyleSheet(
            "QProgressBar { background-color: #151720; border-radius: 6px; height: 12px; text-align: center; color: white; }"
            "QProgressBar::chunk { background-color: #10b981; border-radius: 6px; }"
        )
        f_layout.addWidget(self.enroll_progress)

        self.lbl_enroll_status = QLabel("Ready for biometric registration.")
        self.lbl_enroll_status.setStyleSheet("color: #64748b; font-style: italic;")
        f_layout.addWidget(self.lbl_enroll_status)

        f_layout.addStretch()
        page_layout.addWidget(form_card, 2)

        # Directory Table (Right)
        roster_card = QFrame()
        roster_card.setProperty("class", "neumorphic-card")
        r_layout = QVBoxLayout(roster_card)
        r_layout.setContentsMargins(20, 20, 20, 20)
        r_layout.setSpacing(12)

        r_header = QHBoxLayout()
        r_title = QLabel("Enrolled Students Directory")
        r_title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        r_header.addWidget(r_title)
        r_header.addStretch()

        self.inp_enrolled_search = QLineEdit()
        self.inp_enrolled_search.setPlaceholderText("Search enrolled...")
        self.inp_enrolled_search.setFixedWidth(160)
        self.inp_enrolled_search.textChanged.connect(self.filter_enrolled_table)
        r_header.addWidget(self.inp_enrolled_search)

        btn_refresh_enrolled = QPushButton("  Refresh")
        btn_refresh_enrolled.setIcon(create_vector_icon("refresh", "#e2e8f0", 14))
        btn_refresh_enrolled.clicked.connect(self.refresh_enrolled_table)
        r_header.addWidget(btn_refresh_enrolled)

        r_layout.addLayout(r_header)

        # Enrolled Table with Delete Action Column
        self.table_enrolled = QTableWidget(0, 4)
        self.table_enrolled.setHorizontalHeaderLabels(["ID", "Roll Number", "Full Name", "Action"])
        self.table_enrolled.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.table_enrolled.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeToContents)
        self.table_enrolled.horizontalHeader().setSectionResizeMode(2, QHeaderView.Stretch)
        self.table_enrolled.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeToContents)
        self.table_enrolled.verticalHeader().setVisible(False)
        r_layout.addWidget(self.table_enrolled, 1)

        page_layout.addWidget(roster_card, 3)
        return page

    # =========================================================================
    # PAGE 2: ATTENDANCE LOGS & CORRECTION
    # =========================================================================
    def build_records_page(self) -> QWidget:
        page = QWidget()
        page_layout = QVBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        page_layout.setSpacing(14)

        card = QFrame()
        card.setProperty("class", "neumorphic-card")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(20, 20, 20, 20)
        card_layout.setSpacing(12)

        header_row = QHBoxLayout()
        title = QLabel("Attendance Queue & Verification Logs")
        title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        header_row.addWidget(title)
        header_row.addStretch()

        btn_export = QPushButton("  Export to CSV")
        btn_export.setIcon(create_vector_icon("download", "#ffffff", 14))
        btn_export.setProperty("class", "btn-primary")
        btn_export.clicked.connect(self.on_export_csv_clicked)
        header_row.addWidget(btn_export)

        btn_refresh = QPushButton("  Refresh")
        btn_refresh.setIcon(create_vector_icon("refresh", "#e2e8f0", 14))
        btn_refresh.clicked.connect(self.refresh_records_table)
        header_row.addWidget(btn_refresh)

        card_layout.addLayout(header_row)

        self.table_records = QTableWidget(0, 7)
        self.table_records.setHorizontalHeaderLabels(["Queue ID", "Roll No", "Full Name", "Marked Time", "Method", "Confidence", "Sync Status"])
        self.table_records.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        self.table_records.verticalHeader().setVisible(False)
        card_layout.addWidget(self.table_records, 1)

        page_layout.addWidget(card)
        return page

    # =========================================================================
    # PAGE 3: CLOUD SYNC & DIAGNOSTICS
    # =========================================================================
    def build_sync_page(self) -> QWidget:
        page = QWidget()
        page_layout = QHBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        page_layout.setSpacing(14)

        # Left: Cloud Sync Configuration
        cloud_card = QFrame()
        cloud_card.setProperty("class", "neumorphic-card")
        c_layout = QVBoxLayout(cloud_card)
        c_layout.setContentsMargins(20, 20, 20, 20)
        c_layout.setSpacing(14)

        title = QLabel("Postgres Cloud Synchronization")
        title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        title.setStyleSheet("color: #38bdf8;")
        c_layout.addWidget(title)

        desc = QLabel(
            "Safely relays confirmed attendance records to the FastAPI Cloud backend.\n"
            "Only textual session logs are uploaded; raw biometrics remain offline."
        )
        desc.setStyleSheet("color: #94a3b8; line-height: 1.4;")
        c_layout.addWidget(desc)

        c_layout.addSpacing(10)

        c_layout.addWidget(QLabel("FastAPI Backend Endpoint:"))
        self.inp_backend_url = QLineEdit("http://127.0.0.1:8000")
        c_layout.addWidget(self.inp_backend_url)

        c_layout.addWidget(QLabel("Teacher Account Email:"))
        self.inp_teacher_email = QLineEdit("teacher@univision.edu")
        c_layout.addWidget(self.inp_teacher_email)

        c_layout.addWidget(QLabel("Account Password:"))
        self.inp_teacher_pwd = QLineEdit("teacher123")
        self.inp_teacher_pwd.setEchoMode(QLineEdit.Password)
        c_layout.addWidget(self.inp_teacher_pwd)

        c_layout.addSpacing(10)

        self.btn_sync_now = QPushButton("  Push Queued Attendance to Cloud")
        self.btn_sync_now.setIcon(create_vector_icon("cloud", "#ffffff", 14))
        self.btn_sync_now.setProperty("class", "btn-primary")
        self.btn_sync_now.clicked.connect(self.on_sync_now_clicked)
        c_layout.addWidget(self.btn_sync_now)

        self.lbl_sync_result = QLabel("Status: Idle")
        self.lbl_sync_result.setStyleSheet("color: #94a3b8; font-style: italic;")
        c_layout.addWidget(self.lbl_sync_result)

        c_layout.addStretch()
        page_layout.addWidget(cloud_card, 2)

        # Right: Real-time Diagnostic Log Viewer
        log_card = QFrame()
        log_card.setProperty("class", "neumorphic-card")
        l_layout = QVBoxLayout(log_card)
        l_layout.setContentsMargins(20, 20, 20, 20)
        l_layout.setSpacing(12)

        l_header = QHBoxLayout()
        l_title = QLabel("System Activity & Error Logs")
        l_title.setFont(QFont("Segoe UI", 14, QFont.Bold))
        l_header.addWidget(l_title)
        l_header.addStretch()

        btn_refresh_log = QPushButton("  Refresh Log")
        btn_refresh_log.setIcon(create_vector_icon("refresh", "#e2e8f0", 14))
        btn_refresh_log.clicked.connect(self.refresh_diagnostic_log)
        l_header.addWidget(btn_refresh_log)

        l_layout.addLayout(l_header)

        self.txt_diagnostic_log = QTextEdit()
        self.txt_diagnostic_log.setReadOnly(True)
        self.txt_diagnostic_log.setProperty("class", "neumorphic-sunken")
        self.txt_diagnostic_log.setFont(QFont("Consolas", 10))
        self.txt_diagnostic_log.setStyleSheet("background-color: #12141a; color: #a5b4fc; padding: 10px; border-radius: 8px;")
        l_layout.addWidget(self.txt_diagnostic_log, 1)

        page_layout.addWidget(log_card, 3)
        return page

    # =========================================================================
    # EVENT BUS SUBSCRIPTIONS (EDA)
    # =========================================================================
    def subscribe_to_event_bus(self):
        desktop_event_bus.frame_processed.connect(self.on_frame_processed)
        desktop_event_bus.attendance_confirmed.connect(self.on_attendance_confirmed_event)
        desktop_event_bus.record_queued.connect(self.on_record_queued_event)
        desktop_event_bus.session_started.connect(self.on_session_started_event)
        desktop_event_bus.session_ended.connect(self.on_session_ended_event)
        desktop_event_bus.sync_status_changed.connect(self.on_sync_status_changed_event)

    # =========================================================================
    # SLOTS & EVENT HANDLERS
    # =========================================================================
    @Slot(object, list, float)
    def on_frame_processed(self, display_frame: np.ndarray, detected_faces: list, fps: float):
        """Thread-safe UI slot displaying the processed video frame from CameraWorker."""
        try:
            rgb_image = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
            h, w, ch = rgb_image.shape
            bytes_per_line = ch * w
            q_img = QImage(rgb_image.data, w, h, bytes_per_line, QImage.Format_RGB888).copy()
            pix = QPixmap.fromImage(q_img)
            self.video_label.setPixmap(pix.scaled(self.video_label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
            self.lbl_kpi_fps.setText(f"FPS: {fps:.1f}")
        except Exception:
            pass

    @Slot(int, str, str, float)
    def on_attendance_confirmed_event(self, student_id: int, roll_no: str, full_name: str, confidence: float):
        """Visual flash confirmation when a face is confirmed."""
        self.lbl_confirmed_banner.setText(f"Confirmed: {full_name} ({roll_no}) [{confidence*100:.0f}% similarity]")
        self.lbl_confirmed_banner.setStyleSheet("color: #34d399; font-weight: bold; padding: 2px 4px;")

        # Subtle glowing emerald flash around camera container
        self.video_container.setStyleSheet(
            "QFrame { background-color: #12141a; border-radius: 12px; border: 3px solid #10b981; }"
        )
        self.flash_timer.start(650)

    def clear_camera_flash(self):
        """Restores normal sunken frame after green visual confirmation flash."""
        self.video_container.setStyleSheet("")
        self.video_container.setProperty("class", "neumorphic-sunken")
        self.video_container.style().unpolish(self.video_container)
        self.video_container.style().polish(self.video_container)

    @Slot(dict)
    def on_record_queued_event(self, record: dict):
        """Updates live present roster when attendance record is queued."""
        row = self.table_present.rowCount()
        self.table_present.insertRow(row)
        self.table_present.setItem(row, 0, QTableWidgetItem(record.get("roll_no", "")))
        self.table_present.setItem(row, 1, QTableWidgetItem(record.get("full_name", "")))
        self.table_present.setItem(row, 2, QTableWidgetItem(record.get("time", "")))
        conf_val = record.get("confidence", 1.0)
        self.table_present.setItem(row, 3, QTableWidgetItem(f"{conf_val*100:.0f}%"))

        # QoL: Auto-scroll to latest marked attendee and highlight row
        self.table_present.scrollToBottom()
        self.table_present.selectRow(row)

        self.lbl_kpi_present.setText(f"PRESENT: {self.table_present.rowCount()}")
        self.update_sync_badge_count()

    @Slot(int, str, str)
    def on_session_started_event(self, local_id: int, course_code: str, course_name: str):
        self.lbl_active_header.setText(f"Active Session #{local_id}: {course_code} - {course_name}")
        self.btn_session_toggle.setText("  End Lecture Session")
        self.btn_session_toggle.setIcon(create_vector_icon("stop", "#ffffff", 14))
        self.btn_session_toggle.setProperty("class", "btn-danger")
        self.btn_session_toggle.style().unpolish(self.btn_session_toggle)
        self.btn_session_toggle.style().polish(self.btn_session_toggle)

        self.table_present.setRowCount(0)
        self.lbl_kpi_present.setText("PRESENT: 0")
        self.session_start_time = time.time()
        self.session_timer.start(1000)

    @Slot(int)
    def on_session_ended_event(self, local_id: int):
        self.lbl_active_header.setText(f"Session #{local_id} ended. Ready for next class.")
        self.btn_session_toggle.setText("  Start Lecture Session")
        self.btn_session_toggle.setIcon(create_vector_icon("play", "#ffffff", 14))
        self.btn_session_toggle.setProperty("class", "btn-success")
        self.btn_session_toggle.style().unpolish(self.btn_session_toggle)
        self.btn_session_toggle.style().polish(self.btn_session_toggle)

        self.session_timer.stop()
        self.lbl_session_elapsed.setText("TIME: 00:00:00")
        self.refresh_records_table()

    @Slot(str, dict)
    def on_sync_status_changed_event(self, message: str, stats: dict):
        self.lbl_sync_result.setText(message)
        action = stats.get("action")
        if action == "ENROLLMENT_COMPLETED":
            self.refresh_enrolled_table()
            self.enroll_progress.setValue(5)
            self.lbl_enroll_status.setText("Biometric capture complete!")
            QMessageBox.information(self, "Registration Success", message)
        elif action == "STUDENT_DELETED":
            self.refresh_enrolled_table()
        self.update_sync_badge_count()

    def update_session_elapsed_time(self):
        if self.session_start_time:
            elapsed = int(time.time() - self.session_start_time)
            h = elapsed // 3600
            m = (elapsed % 3600) // 60
            s = elapsed % 60
            self.lbl_session_elapsed.setText(f"TIME: {h:02d}:{m:02d}:{s:02d}")

    # =========================================================================
    # USER ACTIONS & CONTROLLER DELEGATION
    # =========================================================================
    def on_toggle_camera_clicked(self):
        if not self.camera_worker.isRunning():
            cam_idx = self.cb_camera_idx.currentIndex()
            self.camera_worker.camera_index = cam_idx
            self.camera_worker.start()
            self.btn_toggle_cam.setText("  Stop Camera Stream")
            self.btn_toggle_cam.setIcon(create_vector_icon("stop", "#ffffff", 14))
            self.btn_toggle_cam.setProperty("class", "btn-danger")
            self.btn_toggle_cam.style().unpolish(self.btn_toggle_cam)
            self.btn_toggle_cam.style().polish(self.btn_toggle_cam)
        else:
            self.camera_worker.stop_worker()
            self.video_label.setText("Camera Stream Stopped.")
            self.btn_toggle_cam.setText("  Start Camera Stream")
            self.btn_toggle_cam.setIcon(create_vector_icon("video", "#ffffff", 14))
            self.btn_toggle_cam.setProperty("class", "btn-primary")
            self.btn_toggle_cam.style().unpolish(self.btn_toggle_cam)
            self.btn_toggle_cam.style().polish(self.btn_toggle_cam)

    def on_session_toggle_clicked(self):
        if self.session_controller.active_local_session_id is None:
            try:
                cid = int(self.inp_quick_course_id.text().strip())
                ccode = self.inp_quick_course_code.text().strip()
                cname = self.inp_quick_course_name.text().strip()
                if not ccode or not cname:
                    raise ValueError()
            except ValueError:
                QMessageBox.warning(self, "Input Error", "Please provide a valid Course ID, Code, and Name.")
                return

            self.session_controller.start_session(cid, ccode, cname)
            if not self.camera_worker.isRunning():
                self.on_toggle_camera_clicked()
        else:
            sid = self.session_controller.end_session()
            QMessageBox.information(self, "Session Concluded", f"Lecture session #{sid} has concluded.")

    def on_manual_checkin_clicked(self):
        roll = self.inp_manual_roll.text().strip()
        name = self.inp_manual_name.text().strip()
        if not roll or not name:
            QMessageBox.warning(self, "Input Error", "Please enter Roll Number and Name.")
            return

        sid = self.session_controller.active_local_session_id
        if sid is None:
            QMessageBox.warning(self, "No Active Session", "Please start a lecture session first.")
            return

        is_new = self.storage.queue_attendance(
            local_session_id=sid,
            student_id=9999,
            roll_no=roll,
            full_name=name,
            method="manual",
            confidence=1.0,
            cloud_session_id=self.session_controller.active_cloud_session_id
        )

        if is_new:
            record_dict = {
                "student_id": 9999,
                "roll_no": roll,
                "full_name": name,
                "time": datetime.now().strftime("%H:%M:%S"),
                "confidence": 1.0
            }
            desktop_event_bus.record_queued.emit(record_dict)
            self.inp_manual_roll.clear()
            self.inp_manual_name.clear()
        else:
            QMessageBox.information(self, "Notice", f"{roll} is already marked present in this session.")

    def on_start_enroll_clicked(self):
        try:
            sid = int(self.inp_enroll_id.text().strip())
            roll = self.inp_enroll_roll.text().strip()
            name = self.inp_enroll_name.text().strip()
            if not roll or not name:
                raise ValueError()
        except ValueError:
            QMessageBox.warning(self, "Input Error", "Please enter valid Student ID, Roll No, and Name.")
            return

        self.enroll_progress.setValue(1)
        self.lbl_enroll_status.setText("Capturing 5 biometric samples. Face the camera...")
        self.enrollment_controller.request_enrollment(sid, roll, name)

        if not self.camera_worker.isRunning():
            self.on_toggle_camera_clicked()

        self.switch_page(0)

    def on_prefill_sample_student_clicked(self):
        """QoL: Automatically populates demo student info for instant testing."""
        next_id = len(self.storage.list_enrolled_students()) + 1
        self.inp_enroll_id.setText(str(next_id))
        self.inp_enroll_roll.setText(f"2024-CS-{next_id:03d}")
        self.inp_enroll_name.setText(f"Student #{next_id}")

    def on_clear_enroll_form_clicked(self):
        """QoL: Resets the enrollment form."""
        self.inp_enroll_id.clear()
        self.inp_enroll_roll.clear()
        self.inp_enroll_name.clear()
        self.enroll_progress.setValue(0)
        self.lbl_enroll_status.setText("Ready for biometric registration.")

    def on_delete_student_clicked(self, student_id: int, roll_no: str, full_name: str):
        """QoL: Confirmation and deletion of student biometric enrollment."""
        reply = QMessageBox.question(
            self,
            "Confirm Deletion",
            f"Are you sure you want to remove student:\n\n{full_name} ({roll_no})\n\nThis will permanently delete their local face embeddings.",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        if reply == QMessageBox.Yes:
            success = self.enrollment_controller.delete_student(student_id)
            if success:
                QMessageBox.information(self, "Student Deleted", f"Removed {full_name} from enrolled biometrics.")
            else:
                QMessageBox.warning(self, "Error", "Failed to delete student from local database.")

    def on_sync_now_clicked(self):
        url = self.inp_backend_url.text().strip()
        email = self.inp_teacher_email.text().strip()
        pwd = self.inp_teacher_pwd.text().strip()
        self.lbl_sync_result.setText("Connecting and synchronizing...")
        self.sync_controller.sync_to_cloud(url, email, pwd)
        self.refresh_records_table()
        self.update_sync_badge_count()

    def on_export_csv_clicked(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export Attendance CSV", "attendance_export.csv", "CSV Files (*.csv)")
        if path:
            latest_id = self.session_controller.active_local_session_id or 1
            if self.storage.export_session_to_csv(latest_id, path):
                QMessageBox.information(self, "Export Successful", f"Saved attendance records to:\n{path}")
            else:
                QMessageBox.warning(self, "Export Notice", "No attendance records available to export.")

    def filter_live_roster(self, text: str):
        query = text.strip().lower()
        for row in range(self.table_present.rowCount()):
            roll_item = self.table_present.item(row, 0)
            name_item = self.table_present.item(row, 1)
            match = (query in (roll_item.text().lower() if roll_item else "")) or \
                    (query in (name_item.text().lower() if name_item else ""))
            self.table_present.setRowHidden(row, not match)

    def filter_enrolled_table(self, text: str):
        query = text.strip().lower()
        for row in range(self.table_enrolled.rowCount()):
            roll_item = self.table_enrolled.item(row, 1)
            name_item = self.table_enrolled.item(row, 2)
            match = (query in (roll_item.text().lower() if roll_item else "")) or \
                    (query in (name_item.text().lower() if name_item else ""))
            self.table_enrolled.setRowHidden(row, not match)

    def update_sync_badge_count(self):
        pending = self.storage.get_pending_sync_records()
        self.lbl_kpi_sync.setText(f"SYNC QUEUE: {len(pending)}")

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
            status_item.setForeground(QColor("#fbbf24" if r["synced"] == 0 else "#34d399"))
            self.table_records.setItem(row, 6, status_item)
        self.update_sync_badge_count()

    def refresh_enrolled_table(self):
        students = self.storage.list_enrolled_students()
        self.table_enrolled.setRowCount(0)
        for s in students:
            row = self.table_enrolled.rowCount()
            self.table_enrolled.insertRow(row)
            self.table_enrolled.setItem(row, 0, QTableWidgetItem(str(s["student_id"])))
            self.table_enrolled.setItem(row, 1, QTableWidgetItem(s["roll_no"]))
            self.table_enrolled.setItem(row, 2, QTableWidgetItem(s["full_name"]))

            # Action: Sleek Red Delete Button
            btn_del = QPushButton("Delete")
            btn_del.setIcon(create_vector_icon("trash", "#ffffff", 12))
            btn_del.setProperty("class", "btn-danger")
            btn_del.setFixedHeight(28)
            sid = s["student_id"]
            sroll = s["roll_no"]
            sname = s["full_name"]
            btn_del.clicked.connect(lambda ch=False, s_id=sid, r_no=sroll, f_name=sname: self.on_delete_student_clicked(s_id, r_no, f_name))
            self.table_enrolled.setCellWidget(row, 3, btn_del)

    def refresh_diagnostic_log(self):
        log_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "desktop.log")
        if os.path.exists(log_path):
            try:
                with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                    lines = f.readlines()
                    tail_lines = "".join(lines[-100:])
                    self.txt_diagnostic_log.setPlainText(tail_lines)
                    self.txt_diagnostic_log.verticalScrollBar().setValue(
                        self.txt_diagnostic_log.verticalScrollBar().maximum()
                    )
            except Exception as e:
                self.txt_diagnostic_log.setPlainText(f"Error reading log file: {e}")
        else:
            self.txt_diagnostic_log.setPlainText("No desktop.log file found yet.")

    def closeEvent(self, event):
        if self.camera_worker.isRunning():
            self.camera_worker.stop_worker()
        event.accept()
