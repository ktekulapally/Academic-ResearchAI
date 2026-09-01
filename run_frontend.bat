@echo off
title Academic Research AI - Flutter Frontend
echo ===================================================
echo   Academic Research AI - Flutter Web Client
echo ===================================================
echo.
echo [1/2] Changing directory to flutter_app...
cd /d "%~dp0\flutter_app"

echo [2/2] Running Flutter Web client in Chrome...
echo.
flutter run -d chrome
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Flutter run failed. Please make sure Flutter is installed and available in your system Environment Variables (PATH).
    pause
)
