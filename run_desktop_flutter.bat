@echo off
title UniVision Biometric Desktop Station (Flutter GUI)
cd /d "%~dp0"
echo ===============================================================
echo Starting UniVision Biometric Desktop Station (Flutter Desktop)
echo ===============================================================
echo [1/2] Starting Python AI & Storage Bridge Service on port 8001...
start "UniVision AI Bridge" /min python -m uvicorn desktop.app.bridge_service:app --host 127.0.0.1 --port 8001

echo [2/2] Launching Flutter Desktop GUI...
if "%1"=="--dev" goto DEV
if "%1"=="--build" goto BUILD
if exist "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe" (
    echo Launching compiled Windows Release binary...
    start "" "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe"
    exit /b 0
)

:BUILD
echo Compiling latest Windows Release binary...
cd desktop_flutter
call flutter build windows
cd ..
start "" "desktop_flutter\build\windows\x64\runner\Release\desktop_flutter.exe"
exit /b 0

:DEV
echo Compiling and running live in development mode...
cd desktop_flutter
flutter run -d windows
exit /b 0
