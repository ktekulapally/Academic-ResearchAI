import os
import subprocess
from pathlib import Path

# Resolve base workspace root path
base_dir = Path(__file__).resolve().parent.parent

# 1. Write the run.ps1 script
run_ps1_content = f"""# Academic Research AI - Launcher Script
$PSScriptRoot = "{base_dir}"

Write-Host "===================================================" -ForegroundColor Indigo
Write-Host "  Starting Academic Research AI Stack (Serverless)" -ForegroundColor Indigo
Write-Host "===================================================" -ForegroundColor Indigo
Write-Host ""

# 1. Start FastAPI Backend silently in the background
Write-Host "[1/2] Launching backend server silently..." -ForegroundColor Green
$BackendDir = "$PSScriptRoot\\backend"
$PythonExe = "$PSScriptRoot\\.venv\\Scripts\\python.exe"

# Launch uvicorn as a hidden background process
$BackendProcess = Start-Process -FilePath $PythonExe -ArgumentList "-m uvicorn app.main:app --host 127.0.0.1 --port 8000" -WorkingDirectory $BackendDir -WindowStyle Hidden -PassThru

# Sleep 3 seconds for server to initialize SQLite tables
Start-Sleep -Seconds 3

# 2. Launch Flutter Frontend in Chrome
Write-Host "[2/2] Running Flutter Web client in Chrome..." -ForegroundColor Green
$FrontendDir = "$PSScriptRoot\\flutter_app"
Start-Process -FilePath "flutter" -ArgumentList "run -d chrome" -WorkingDirectory $FrontendDir -WindowStyle Normal
"""

run_ps1_path = base_dir / "run.ps1"
with open(run_ps1_path, "w", encoding="utf-8") as f:
    f.write(run_ps1_content)
print(f"Created script: {run_ps1_path}")

# 2. Detect Desktop Directory
user_home = Path(os.path.expanduser("~"))
onedrive_desktop = user_home / "OneDrive" / "Desktop"
normal_desktop = user_home / "Desktop"

desktop_dir = normal_desktop
if onedrive_desktop.exists():
    desktop_dir = onedrive_desktop

shortcut_path = desktop_dir / "Academic Research AI.lnk"
print(f"Target Desktop Path: {shortcut_path}")

# 3. Create Windows Shortcut using PowerShell COM Object (using single quotes)
ps_shortcut_command = f"""
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut('{shortcut_path}')
$Shortcut.TargetPath = 'powershell.exe'
$Shortcut.Arguments = '-ExecutionPolicy Bypass -File "{run_ps1_path}"'
$Shortcut.WorkingDirectory = '{base_dir}'
$Shortcut.Description = 'Academic Research AI deep RAG tool'
$Shortcut.Save()
"""

try:
    subprocess.run(["powershell", "-Command", ps_shortcut_command], check=True)
    print(f"Successfully created Desktop Shortcut: {shortcut_path}")
except Exception as e:
    print(f"Error creating shortcut: {e}")
