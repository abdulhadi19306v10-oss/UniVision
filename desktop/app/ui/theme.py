"""
Dark Neumorphism (Soft UI) Theme for UniVision / Focus Attendance.
Provides custom QSS stylesheets with embossed (raised) and debossed (sunken)
soft dual-shadow effects for modern biometrics dashboards.
"""

NEUMORPHIC_DARK_QSS = """
/* Global Window & Typography */
QMainWindow {
    background-color: #1a1d26;
    color: #f1f5f9;
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
}

QWidget {
    color: #f1f5f9;
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
    font-size: 13px;
}

/* Sidebar Container */
#sidebar {
    background-color: #171922;
    border-right: 2px solid rgba(0, 0, 0, 0.6);
    border-top: 1px solid rgba(255, 255, 255, 0.04);
}

/* Navigation Buttons in Sidebar */
QPushButton.nav-btn {
    background-color: #1d212c;
    color: #94a3b8;
    border: none;
    border-radius: 10px;
    padding: 12px 18px;
    text-align: left;
    font-size: 14px;
    font-weight: 600;
    margin: 4px 10px;
    border-top: 1px solid rgba(255, 255, 255, 0.06);
    border-left: 1px solid rgba(255, 255, 255, 0.06);
    border-bottom: 2px solid rgba(0, 0, 0, 0.4);
    border-right: 2px solid rgba(0, 0, 0, 0.4);
}

QPushButton.nav-btn:hover {
    background-color: #242937;
    color: #e2e8f0;
    border-top: 1px solid rgba(255, 255, 255, 0.12);
}

QPushButton.nav-btn:checked, QPushButton.nav-btn[active="true"] {
    background-color: #13151c;
    color: #38bdf8;
    border-top: 2px solid rgba(0, 0, 0, 0.8);
    border-left: 4px solid #38bdf8;
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    border-right: 1px solid rgba(255, 255, 255, 0.04);
}

/* Neumorphic Raised Panels */
QFrame.neumorphic-card {
    background-color: #202431;
    border-radius: 14px;
    border-top: 1px solid rgba(255, 255, 255, 0.09);
    border-left: 1px solid rgba(255, 255, 255, 0.09);
    border-bottom: 2px solid rgba(0, 0, 0, 0.5);
    border-right: 2px solid rgba(0, 0, 0, 0.5);
}

/* Sunken / Inset Frames (e.g. Video Container, Search Input) */
QFrame.neumorphic-sunken {
    background-color: #12141a;
    border-radius: 12px;
    border-top: 2px solid rgba(0, 0, 0, 0.7);
    border-left: 2px solid rgba(0, 0, 0, 0.7);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    border-right: 1px solid rgba(255, 255, 255, 0.05);
}

/* KPI Stat Cards */
QFrame.kpi-card {
    background-color: #202431;
    border-radius: 12px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
    border-left: 1px solid rgba(255, 255, 255, 0.08);
    border-bottom: 2px solid rgba(0, 0, 0, 0.45);
    border-right: 2px solid rgba(0, 0, 0, 0.45);
    padding: 8px 14px;
}

/* Input Fields (Sunken Neumorphism) */
QLineEdit, QComboBox {
    background-color: #14161e;
    color: #f8fafc;
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 13px;
    border-top: 2px solid rgba(0, 0, 0, 0.6);
    border-left: 2px solid rgba(0, 0, 0, 0.6);
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    border-right: 1px solid rgba(255, 255, 255, 0.06);
}

QLineEdit:focus, QComboBox:focus {
    border-top: 2px solid #0369a1;
    border-left: 2px solid #0369a1;
    border-bottom: 1px solid #38bdf8;
    border-right: 1px solid #38bdf8;
}

/* General Buttons (Raised Neumorphism) */
QPushButton {
    background-color: #252a39;
    color: #e2e8f0;
    border-radius: 8px;
    padding: 9px 18px;
    font-weight: 600;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    border-left: 1px solid rgba(255, 255, 255, 0.1);
    border-bottom: 2px solid rgba(0, 0, 0, 0.45);
    border-right: 2px solid rgba(0, 0, 0, 0.45);
}

QPushButton:hover {
    background-color: #2d3345;
    color: #ffffff;
    border-top: 1px solid rgba(255, 255, 255, 0.18);
}

QPushButton:pressed {
    background-color: #161821;
    border-top: 2px solid rgba(0, 0, 0, 0.7);
    border-left: 2px solid rgba(0, 0, 0, 0.7);
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    border-right: 1px solid rgba(255, 255, 255, 0.06);
}

/* Primary Action Button (Cyan Accent) */
QPushButton.btn-primary {
    background-color: #0284c7;
    color: #ffffff;
    border-top: 1px solid rgba(255, 255, 255, 0.25);
    border-left: 1px solid rgba(255, 255, 255, 0.25);
    border-bottom: 2px solid rgba(0, 0, 0, 0.4);
    border-right: 2px solid rgba(0, 0, 0, 0.4);
}

QPushButton.btn-primary:hover {
    background-color: #0369a1;
}

QPushButton.btn-primary:pressed {
    background-color: #075985;
    border-top: 2px solid rgba(0, 0, 0, 0.6);
}

/* Success Button (Emerald Accent) */
QPushButton.btn-success {
    background-color: #059669;
    color: #ffffff;
    border-top: 1px solid rgba(255, 255, 255, 0.25);
    border-left: 1px solid rgba(255, 255, 255, 0.25);
    border-bottom: 2px solid rgba(0, 0, 0, 0.4);
    border-right: 2px solid rgba(0, 0, 0, 0.4);
}

QPushButton.btn-success:hover {
    background-color: #047857;
}

/* Danger Button (Crimson Accent) */
QPushButton.btn-danger {
    background-color: #dc2626;
    color: #ffffff;
    border-top: 1px solid rgba(255, 255, 255, 0.25);
    border-left: 1px solid rgba(255, 255, 255, 0.25);
    border-bottom: 2px solid rgba(0, 0, 0, 0.4);
    border-right: 2px solid rgba(0, 0, 0, 0.4);
}

QPushButton.btn-danger:hover {
    background-color: #b91c1c;
}

/* Tables (Sunken background with sleek modern headers) */
QTableWidget {
    background-color: #151720;
    color: #e2e8f0;
    gridline-color: rgba(255, 255, 255, 0.04);
    border-radius: 10px;
    border-top: 2px solid rgba(0, 0, 0, 0.6);
    border-left: 2px solid rgba(0, 0, 0, 0.6);
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    border-right: 1px solid rgba(255, 255, 255, 0.05);
}

QTableWidget::item {
    padding: 6px 10px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
}

QTableWidget::item:selected {
    background-color: #1e3a5f;
    color: #38bdf8;
}

QHeaderView::section {
    background-color: #1e222f;
    color: #94a3b8;
    padding: 8px 10px;
    font-weight: 600;
    border: none;
    border-bottom: 2px solid rgba(0, 0, 0, 0.4);
}

/* Scrollbars */
QScrollBar:vertical {
    background: #14161e;
    width: 8px;
    border-radius: 4px;
}
QScrollBar::handle:vertical {
    background: #33394a;
    border-radius: 4px;
    min-height: 20px;
}
QScrollBar::handle:vertical:hover {
    background: #475569;
}

/* Badges */
QLabel.badge-emerald {
    background-color: #064e3b;
    color: #34d399;
    padding: 4px 10px;
    border-radius: 8px;
    font-weight: bold;
    font-size: 11px;
}

QLabel.badge-cyan {
    background-color: #083344;
    color: #38bdf8;
    padding: 4px 10px;
    border-radius: 8px;
    font-weight: bold;
    font-size: 11px;
}

QLabel.badge-amber {
    background-color: #451a03;
    color: #fbbf24;
    padding: 4px 10px;
    border-radius: 8px;
    font-weight: bold;
    font-size: 11px;
}
"""
