@echo off
rem Launcher for Flutter Desktop Application
cd /d "%~dp0"
if exist "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe" (
    start "UniVision AI Bridge" /min python -m uvicorn desktop.app.bridge_service:app --host 127.0.0.1 --port 8001
    start "" "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe"
) else (
    start "UniVision AI Bridge" /min python -m uvicorn desktop.app.bridge_service:app --host 127.0.0.1 --port 8001
    cd desktop_flutter
    flutter run -d windows
)
