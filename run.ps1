# Academic Research AI - Launcher Script
$PSScriptRoot = "D:\Develop\Academic-ResearchAI"

Write-Host "===================================================" -ForegroundColor Indigo
Write-Host "  Starting Academic Research AI Stack (Serverless)" -ForegroundColor Indigo
Write-Host "===================================================" -ForegroundColor Indigo
Write-Host ""

# 1. Start FastAPI Backend silently in the background
Write-Host "[1/2] Launching backend server silently..." -ForegroundColor Green
$BackendDir = "$PSScriptRoot\backend"
$PythonExe = "$PSScriptRoot\.venv\Scripts\python.exe"

# Launch uvicorn as a hidden background process
$BackendProcess = Start-Process -FilePath $PythonExe -ArgumentList "-m uvicorn app.main:app --host 127.0.0.1 --port 8000" -WorkingDirectory $BackendDir -WindowStyle Hidden -PassThru

# Sleep 3 seconds for server to initialize SQLite tables
Start-Sleep -Seconds 3

# 2. Launch Flutter Frontend in Chrome
Write-Host "[2/2] Running Flutter Web client in Chrome..." -ForegroundColor Green
$FrontendDir = "$PSScriptRoot\flutter_app"
Start-Process -FilePath "flutter" -ArgumentList "run -d chrome" -WorkingDirectory $FrontendDir -WindowStyle Normal
