@echo off
title UniVision Biometric Desktop Station
cd /d "%~dp0"
echo ===================================================
echo Starting UniVision Biometric Station (MVC + EDA)...
echo ===================================================
python desktop\app\main.py
if errorlevel 1 (
    echo.
    echo An error occurred while running the application.
    pause
)
