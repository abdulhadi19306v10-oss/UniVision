@echo off
title UniVision Biometric Desktop Station (Flutter GUI)
cd /d "%~dp0"
echo ===============================================================
echo Starting UniVision Biometric Desktop Station (Flutter Desktop)
echo ===============================================================
echo [1/2] Starting Python AI & Storage Bridge Service on port 8001...
start "UniVision AI Bridge" /min python -m uvicorn desktop.app.bridge_service:app --host 127.0.0.1 --port 8001

echo [2/2] Launching Flutter Desktop GUI...
if exist "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe" (
    echo Launching compiled Windows Release binary...
    start "" "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe"
) else (
    echo Compiling and running in development mode...
    cd desktop_flutter
    flutter run -d windows
)
