@echo off
title UniVision Biometric Desktop Station (Flutter Desktop)
cd /d "%~dp0"
echo ===============================================================
echo Starting UniVision Biometric Desktop Station (Flutter Desktop)
echo ===============================================================
echo [1/2] Starting Python AI & Storage Bridge Service on port 8001...
start "UniVision AI Bridge" /min python -m uvicorn desktop.app.bridge_service:app --host 127.0.0.1 --port 8001

echo [2/2] Launching Flutter Desktop GUI...
cd desktop_flutter
flutter run -d windows
if errorlevel 1 (
    echo.
    echo An error occurred while running the Flutter Desktop application.
    pause
)
