import sys
import os
import logging

# Put desktop root on sys.path
desktop_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, desktop_dir)

log_file = os.path.join(desktop_dir, "desktop.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(threadName)s) %(name)s: %(message)s",
    handlers=[
        logging.FileHandler(log_file, mode="a", encoding="utf-8"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("DesktopMain")

from PySide6.QtWidgets import QApplication
from app.ui.main_window import MainWindow

def main():
    logger.info("Starting UniVision Desktop Application...")
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()

