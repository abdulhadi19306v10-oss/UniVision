import logging
from typing import Optional
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit,
    QPushButton, QFrame, QSpacerItem, QSizePolicy
)
from PySide6.QtGui import QFont
from PySide6.QtCore import Qt, Signal, Slot, QSize

from .icons import create_vector_icon
from ..storage.local_db import LocalStorage
from ..storage.sync_client import CloudSyncClient

logger = logging.getLogger("LoginView")

class LoginView(QWidget):
    """
    Sleek Neumorphic Dark Login Interface for UniVision Biometric Station.
    Provides role-based authentication for Admin, Teacher, and Student.
    Offline-first SQLite verification with cloud backend fallback.
    """
    login_successful = Signal(dict)

    def __init__(self, storage: LocalStorage, sync_client: Optional[CloudSyncClient] = None, parent=None):
        super().__init__(parent)
        self.storage = storage
        self.sync_client = sync_client
        self.active_role = "admin"  # Default role
        self.setup_ui()

    def setup_ui(self):
        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(40, 30, 40, 30)
        root_layout.setAlignment(Qt.AlignCenter)

        # Center Neumorphic Login Card
        card = QFrame()
        card.setProperty("class", "neumorphic-card")
        card.setFixedWidth(480)
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(36, 32, 36, 32)
        card_layout.setSpacing(16)

        # 1. Branding Header
        header_box = QVBoxLayout()
        header_box.setSpacing(4)
        header_box.setAlignment(Qt.AlignCenter)

        icon_lbl = QLabel()
        icon_lbl.setAlignment(Qt.AlignCenter)
        icon_lbl.setPixmap(create_vector_icon("shield", "#38bdf8", 40).pixmap(40, 40))
        self.icon_lbl = icon_lbl
        header_box.addWidget(icon_lbl)

        title = QLabel("UNIVISION")
        title.setFont(QFont("Segoe UI", 22, QFont.Bold))
        title.setStyleSheet("color: #38bdf8; letter-spacing: 2px;")
        title.setAlignment(Qt.AlignCenter)
        header_box.addWidget(title)

        subtitle = QLabel("Biometric Station & Attendance Portal")
        subtitle.setFont(QFont("Segoe UI", 11, QFont.DemiBold))
        subtitle.setStyleSheet("color: #94a3b8;")
        subtitle.setAlignment(Qt.AlignCenter)
        header_box.addWidget(subtitle)

        card_layout.addLayout(header_box)

        # 2. Role Selector Tabs
        role_label = QLabel("Select Account Type:")
        role_label.setStyleSheet("color: #64748b; font-size: 11px; font-weight: bold; letter-spacing: 1px;")
        card_layout.addWidget(role_label)

        role_row = QHBoxLayout()
        role_row.setSpacing(8)

        self.btn_role_admin = QPushButton("  Admin")
        self.btn_role_admin.setIcon(create_vector_icon("shield", "#ffffff", 14))
        self.btn_role_admin.setCheckable(True)
        self.btn_role_admin.setChecked(True)
        self.btn_role_admin.setProperty("class", "btn-primary")
        self.btn_role_admin.clicked.connect(lambda: self.set_role("admin"))
        role_row.addWidget(self.btn_role_admin)

        self.btn_role_teacher = QPushButton("  Teacher")
        self.btn_role_teacher.setIcon(create_vector_icon("chalkboard", "#94a3b8", 14))
        self.btn_role_teacher.setCheckable(True)
        self.btn_role_teacher.clicked.connect(lambda: self.set_role("teacher"))
        role_row.addWidget(self.btn_role_teacher)

        self.btn_role_student = QPushButton("  Student")
        self.btn_role_student.setIcon(create_vector_icon("student", "#94a3b8", 14))
        self.btn_role_student.setCheckable(True)
        self.btn_role_student.clicked.connect(lambda: self.set_role("student"))
        role_row.addWidget(self.btn_role_student)

        card_layout.addLayout(role_row)

        # Dynamic Role Description Helper
        self.lbl_role_desc = QLabel("Admin Access: View all attendance logs and enroll students via biometrics.")
        self.lbl_role_desc.setWordWrap(True)
        self.lbl_role_desc.setStyleSheet("color: #94a3b8; font-size: 11px; font-style: italic; min-height: 28px;")
        card_layout.addWidget(self.lbl_role_desc)

        card_layout.addSpacing(4)

        # 3. Input Fields
        self.lbl_id_prompt = QLabel("Username or Email:")
        self.lbl_id_prompt.setStyleSheet("color: #cbd5e1; font-weight: 600;")
        card_layout.addWidget(self.lbl_id_prompt)

        self.inp_identifier = QLineEdit()
        self.inp_identifier.setPlaceholderText("e.g. admin or admin@univision.edu")
        self.inp_identifier.setText("admin")
        self.inp_identifier.returnPressed.connect(self.focus_password_or_submit)
        card_layout.addWidget(self.inp_identifier)

        lbl_pwd = QLabel("Password:")
        lbl_pwd.setStyleSheet("color: #cbd5e1; font-weight: 600;")
        card_layout.addWidget(lbl_pwd)

        self.inp_password = QLineEdit()
        self.inp_password.setEchoMode(QLineEdit.Password)
        self.inp_password.setPlaceholderText("Enter your password")
        self.inp_password.setText("admin123")
        self.inp_password.returnPressed.connect(self.on_submit_clicked)
        card_layout.addWidget(self.inp_password)

        # Error / Feedback Banner
        self.lbl_error = QLabel("")
        self.lbl_error.setWordWrap(True)
        self.lbl_error.setStyleSheet("color: #f87171; font-weight: bold; font-size: 12px; padding: 2px 0;")
        self.lbl_error.hide()
        card_layout.addWidget(self.lbl_error)

        # 4. Primary Sign In Button
        self.btn_submit = QPushButton("  Sign In to UniVision")
        self.btn_submit.setIcon(create_vector_icon("lock", "#ffffff", 14))
        self.btn_submit.setProperty("class", "btn-primary")
        self.btn_submit.setFixedHeight(40)
        self.btn_submit.clicked.connect(self.on_submit_clicked)
        card_layout.addWidget(self.btn_submit)

        # 5. Quick One-Click Demo Logins
        card_layout.addSpacing(6)
        demo_divider = QLabel("— OR 1-CLICK DEMO ACCESS —")
        demo_divider.setAlignment(Qt.AlignCenter)
        demo_divider.setStyleSheet("color: #64748b; font-size: 10px; font-weight: bold; letter-spacing: 1px;")
        card_layout.addWidget(demo_divider)

        demo_row = QHBoxLayout()
        demo_row.setSpacing(6)

        btn_demo_admin = QPushButton("Demo Admin")
        btn_demo_admin.setFixedHeight(28)
        btn_demo_admin.setStyleSheet("font-size: 11px; padding: 4px 8px;")
        btn_demo_admin.clicked.connect(lambda: self.quick_demo_login("admin", "admin", "admin123"))
        demo_row.addWidget(btn_demo_admin)

        btn_demo_teacher = QPushButton("Demo Teacher")
        btn_demo_teacher.setFixedHeight(28)
        btn_demo_teacher.setStyleSheet("font-size: 11px; padding: 4px 8px;")
        btn_demo_teacher.clicked.connect(lambda: self.quick_demo_login("teacher", "teacher", "teacher123"))
        demo_row.addWidget(btn_demo_teacher)

        btn_demo_student = QPushButton("Demo Student")
        btn_demo_student.setFixedHeight(28)
        btn_demo_student.setStyleSheet("font-size: 11px; padding: 4px 8px;")
        btn_demo_student.clicked.connect(lambda: self.quick_demo_login("student", "2025(s)-SE-5", "student123"))
        demo_row.addWidget(btn_demo_student)

        card_layout.addLayout(demo_row)

        root_layout.addWidget(card)

    def set_role(self, role: str):
        self.active_role = role
        self.lbl_error.hide()

        # Update button states
        self.btn_role_admin.setChecked(role == "admin")
        self.btn_role_admin.setProperty("class", "btn-primary" if role == "admin" else "")
        self.btn_role_admin.setIcon(create_vector_icon("shield", "#ffffff" if role == "admin" else "#94a3b8", 14))

        self.btn_role_teacher.setChecked(role == "teacher")
        self.btn_role_teacher.setProperty("class", "btn-primary" if role == "teacher" else "")
        self.btn_role_teacher.setIcon(create_vector_icon("chalkboard", "#ffffff" if role == "teacher" else "#94a3b8", 14))

        self.btn_role_student.setChecked(role == "student")
        self.btn_role_student.setProperty("class", "btn-primary" if role == "student" else "")
        self.btn_role_student.setIcon(create_vector_icon("student", "#ffffff" if role == "student" else "#94a3b8", 14))

        for btn in [self.btn_role_admin, self.btn_role_teacher, self.btn_role_student]:
            btn.style().unpolish(btn)
            btn.style().polish(btn)

        # Update header icon and hints
        if role == "admin":
            self.icon_lbl.setPixmap(create_vector_icon("shield", "#38bdf8", 40).pixmap(40, 40))
            self.lbl_role_desc.setText("Admin Console: View all attendance logs and enroll students via biometrics.")
            self.lbl_id_prompt.setText("Admin Username or Email:")
            self.inp_identifier.setPlaceholderText("e.g. admin or admin@univision.edu")
            self.inp_identifier.setText("admin")
            self.inp_password.setText("admin123")
        elif role == "teacher":
            self.icon_lbl.setPixmap(create_vector_icon("chalkboard", "#38bdf8", 40).pixmap(40, 40))
            self.lbl_role_desc.setText("Teacher Station: Start class sessions, live AI face HUD, and view student attendance.")
            self.lbl_id_prompt.setText("Teacher Email or Username:")
            self.inp_identifier.setPlaceholderText("e.g. teacher@school.edu or teacher")
            self.inp_identifier.setText("teacher")
            self.inp_password.setText("teacher123")
        elif role == "student":
            self.icon_lbl.setPixmap(create_vector_icon("student", "#a855f7", 40).pixmap(40, 40))
            self.lbl_role_desc.setText("Student Portal: Check your attendance records, course history, and verification status.")
            self.lbl_id_prompt.setText("Student Roll Number or Email:")
            self.inp_identifier.setPlaceholderText("e.g. 2025(s)-SE-5 or 2024-CS-001")
            self.inp_identifier.setText("2025(s)-SE-5")
            self.inp_password.setText("student123")

    def focus_password_or_submit(self):
        if not self.inp_password.text().strip():
            self.inp_password.setFocus()
        else:
            self.on_submit_clicked()

    def quick_demo_login(self, role: str, identifier: str, password: str):
        self.set_role(role)
        self.inp_identifier.setText(identifier)
        self.inp_password.setText(password)
        self.on_submit_clicked()

    def on_submit_clicked(self):
        ident = self.inp_identifier.text().strip()
        pwd = self.inp_password.text().strip()

        if not ident or not pwd:
            self.lbl_error.setText("Please enter both username/roll number and password.")
            self.lbl_error.show()
            return

        # 1. Authenticate against local SQLite storage (Offline-first)
        user = self.storage.authenticate_user(ident, pwd, role=self.active_role)

        # 2. Cloud Fallback (If teacher and local check fails, check backend FastAPI)
        if not user and self.active_role == "teacher" and self.sync_client:
            try:
                ok = self.sync_client.login_teacher(ident, pwd)
                if ok:
                    user = {
                        "id": 999,
                        "username": ident,
                        "email": ident,
                        "role": "teacher",
                        "full_name": "Teacher (Cloud Authenticated)",
                        "roll_no": None
                    }
            except Exception:
                pass

        if user:
            self.lbl_error.hide()
            logger.info("Login successful for user: %s (role: %s)", user.get("username"), user.get("role"))
            self.login_successful.emit(user)
        else:
            self.lbl_error.setText(f"Invalid credentials for {self.active_role.capitalize()}. Please check your details.")
            self.lbl_error.show()

    def reset_view(self):
        """Resets fields when returning to login view."""
        self.lbl_error.hide()
        self.inp_password.clear()
        self.set_role("admin")
