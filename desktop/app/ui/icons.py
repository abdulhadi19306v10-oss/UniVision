"""
Vector Icon Provider for UniVision Desktop Application.
Generates clean, professional, high-resolution vector QIcons using QPainter.
Eliminates OS emoji inconsistencies and delivers sharp, modern iconography at any DPI.
"""

from PySide6.QtGui import QIcon, QPixmap, QPainter, QColor, QPen, QBrush, QPolygonF
from PySide6.QtCore import Qt, QPointF, QRectF

def create_vector_icon(icon_type: str, color_hex: str = "#94a3b8", size: int = 24) -> QIcon:
    """
    Renders crisp, professional minimalist line icons directly to QIcon.
    """
    pixmap = QPixmap(size, size)
    pixmap.fill(Qt.transparent)

    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.Antialiasing)

    color = QColor(color_hex)
    pen = QPen(color, 2, Qt.SolidLine, Qt.RoundCap, Qt.RoundJoin)
    painter.setPen(pen)

    pad = 3.0
    w = float(size)
    h = float(size)

    if icon_type == "video":
        # Camera body and lens triangle
        painter.drawRoundedRect(QRectF(pad, pad + 2, 12, 10), 2, 2)
        lens = QPolygonF([
            QPointF(15, pad + 5),
            QPointF(w - pad, pad + 2),
            QPointF(w - pad, h - pad - 2),
            QPointF(15, pad + 9)
        ])
        painter.setBrush(QBrush(color))
        painter.drawPolygon(lens)

    elif icon_type == "user":
        # Head circle + shoulders arc
        painter.drawEllipse(QPointF(w / 2, 8), 3.5, 3.5)
        painter.drawArc(QRectF(pad + 1, 12, w - 2 * pad - 2, 10), 0 * 16, 180 * 16)

    elif icon_type == "logs":
        # Clipboard / sheet with rows
        painter.drawRoundedRect(QRectF(pad + 1, pad, 14, 18), 2, 2)
        painter.drawLine(QPointF(pad + 4, 8), QPointF(pad + 12, 8))
        painter.drawLine(QPointF(pad + 4, 12), QPointF(pad + 12, 12))
        painter.drawLine(QPointF(pad + 4, 16), QPointF(pad + 9, 16))

    elif icon_type == "cloud":
        # Cloud outline
        painter.drawArc(QRectF(pad + 1, 9, 7, 7), 60 * 16, 180 * 16)
        painter.drawArc(QRectF(pad + 5, 5, 9, 9), 30 * 16, 170 * 16)
        painter.drawArc(QRectF(pad + 11, 8, 7, 7), -40 * 16, 180 * 16)
        painter.drawLine(QPointF(pad + 1, 16), QPointF(pad + 16, 16))

    elif icon_type == "trash":
        # Trash bin and lid
        painter.drawLine(QPointF(pad + 1, 6), QPointF(w - pad - 1, 6)) # Lid bar
        painter.drawLine(QPointF(w / 2 - 2, pad + 1), QPointF(w / 2 + 2, pad + 1)) # Lid handle
        painter.drawRoundedRect(QRectF(pad + 3, 6, 12, 13), 2, 2) # Can
        painter.drawLine(QPointF(pad + 6, 9), QPointF(pad + 6, 16))
        painter.drawLine(QPointF(pad + 9, 9), QPointF(pad + 9, 16))
        painter.drawLine(QPointF(pad + 12, 9), QPointF(pad + 12, 16))

    elif icon_type == "play":
        # Triangle play symbol
        tri = QPolygonF([
            QPointF(pad + 3, pad + 1),
            QPointF(w - pad - 2, h / 2),
            QPointF(pad + 3, h - pad - 1)
        ])
        painter.setBrush(QBrush(color))
        painter.drawPolygon(tri)

    elif icon_type == "stop":
        # Rounded square stop symbol
        painter.setBrush(QBrush(color))
        painter.drawRoundedRect(QRectF(pad + 2, pad + 2, 14, 14), 2, 2)

    elif icon_type == "refresh":
        # Circular refresh arc with arrow
        painter.drawArc(QRectF(pad + 1, pad + 1, 16, 16), 30 * 16, 280 * 16)
        painter.drawLine(QPointF(18, pad + 1), QPointF(18, pad + 6))
        painter.drawLine(QPointF(18, pad + 1), QPointF(13, pad + 1))

    elif icon_type == "download":
        # Down arrow + tray
        painter.drawLine(QPointF(w / 2, pad + 1), QPointF(w / 2, 14))
        painter.drawLine(QPointF(w / 2 - 4, 10), QPointF(w / 2, 14))
        painter.drawLine(QPointF(w / 2 + 4, 10), QPointF(w / 2, 14))
        painter.drawLine(QPointF(pad + 1, 18), QPointF(w - pad - 1, 18))

    elif icon_type == "check":
        # Checkmark
        pen.setWidth(3)
        painter.setPen(pen)
        painter.drawLine(QPointF(pad + 2, 12), QPointF(9, 17))
        painter.drawLine(QPointF(9, 17), QPointF(w - pad - 1, 6))

    elif icon_type == "search":
        # Magnifying glass
        painter.drawEllipse(QPointF(9, 9), 5.5, 5.5)
        painter.drawLine(QPointF(13, 13), QPointF(w - pad, h - pad))

    elif icon_type == "plus":
        # Plus add
        painter.drawLine(QPointF(w / 2, pad + 2), QPointF(w / 2, h - pad - 2))
        painter.drawLine(QPointF(pad + 2, h / 2), QPointF(w - pad - 2, h / 2))

    elif icon_type == "logout":
        # Door frame + arrow pointing right
        painter.drawPolyline([
            QPointF(11, pad + 2),
            QPointF(pad + 2, pad + 2),
            QPointF(pad + 2, h - pad - 2),
            QPointF(11, h - pad - 2)
        ])
        painter.drawLine(QPointF(8, h / 2), QPointF(w - pad - 2, h / 2))
        painter.drawLine(QPointF(w - pad - 6, h / 2 - 4), QPointF(w - pad - 2, h / 2))
        painter.drawLine(QPointF(w - pad - 6, h / 2 + 4), QPointF(w - pad - 2, h / 2))

    elif icon_type == "lock":
        # Padlock body + shackle
        painter.drawRoundedRect(QRectF(pad + 3, 10, 12, 9), 2, 2)
        painter.drawArc(QRectF(pad + 5, pad + 1, 8, 10), 0 * 16, 180 * 16)

    elif icon_type == "shield":
        # Admin shield outline
        shield_pts = QPolygonF([
            QPointF(w / 2, pad + 1),
            QPointF(w - pad - 2, pad + 4),
            QPointF(w - pad - 3, h - 9),
            QPointF(w / 2, h - pad - 1),
            QPointF(pad + 3, h - 9),
            QPointF(pad + 2, pad + 4)
        ])
        painter.drawPolygon(shield_pts)

    elif icon_type == "chalkboard":
        # Teacher blackboard
        painter.drawRoundedRect(QRectF(pad + 1, pad + 2, 16, 12), 2, 2)
        painter.drawLine(QPointF(pad + 1, h - pad - 3), QPointF(w - pad - 1, h - pad - 3))
        painter.drawLine(QPointF(pad + 4, h - pad - 3), QPointF(pad + 2, h - pad + 1))
        painter.drawLine(QPointF(w - pad - 4, h - pad - 3), QPointF(w - pad - 2, h - pad + 1))

    elif icon_type == "student":
        # Mortarboard graduation cap
        cap_poly = QPolygonF([
            QPointF(w / 2, pad + 2),
            QPointF(w - pad - 1, 8),
            QPointF(w / 2, 13),
            QPointF(pad + 1, 8)
        ])
        painter.drawPolygon(cap_poly)
        painter.drawArc(QRectF(pad + 4, 11, 10, 7), 180 * 16, 180 * 16)
        painter.drawLine(QPointF(w - pad - 1, 8), QPointF(w - pad - 1, 15))

    elif icon_type == "history":
        # Clock face + hands
        painter.drawEllipse(QPointF(w / 2, h / 2), 7.5, 7.5)
        painter.drawLine(QPointF(w / 2, h / 2), QPointF(w / 2, 7))
        painter.drawLine(QPointF(w / 2, h / 2), QPointF(15, h / 2))

    painter.end()
    return QIcon(pixmap)
