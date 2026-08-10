@echo off
title Academic Research AI - FastAPI Backend
echo ===================================================
echo   Academic Research AI - FastAPI Backend Server
echo ===================================================
echo.
echo [1/2] Changing directory to backend...
cd /d "%~dp0\backend"

echo [2/2] Starting Uvicorn API Server on http://localhost:8000 ...
echo.
"..\\.venv\\Scripts\\python.exe" -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Uvicorn failed to start.
    pause
)
