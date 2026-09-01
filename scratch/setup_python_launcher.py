import os
import subprocess
from pathlib import Path

# Resolve base workspace root path
base_dir = Path(__file__).resolve().parent.parent

# 1. Write the run.py script
run_py_content = f"""import subprocess
import time
import sys
from pathlib import Path

base_dir = Path(__file__).resolve().parent

# 1. Start FastAPI Backend silently in the background (no console window)
backend_dir = base_dir / "backend"
python_exe = base_dir / ".venv" / "Scripts" / "python.exe"

backend_proc = subprocess.Popen(
    [str(python_exe), "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000"],
    cwd=str(backend_dir),
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    creationflags=0x08000000 # CREATE_NO_WINDOW
)

# Sleep 3 seconds for server to initialize
time.sleep(3)

# 2. Launch Flutter Frontend in Chrome silently in the background
frontend_dir = base_dir / "flutter_app"
flutter_proc = subprocess.Popen(
    ["flutter", "run", "-d", "chrome"],
    cwd=str(frontend_dir),
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    creationflags=0x08000000 # CREATE_NO_WINDOW
)
"""

run_py_path = base_dir / "run.py"
with open(run_py_path, "w", encoding="utf-8") as f:
    f.write(run_py_content)
print(f"Created script: {run_py_path}")

# 2. Detect Desktop Directory
user_home = Path(os.path.expanduser("~"))
onedrive_desktop = user_home / "OneDrive" / "Desktop"
normal_desktop = user_home / "Desktop"

desktop_dir = normal_desktop
if onedrive_desktop.exists():
    desktop_dir = onedrive_desktop

shortcut_path = desktop_dir / "Academic Research AI.lnk"
pythonw_exe = base_dir / ".venv" / "Scripts" / "pythonw.exe"
print(f"Target Desktop Path: {shortcut_path}")

# 3. Create Windows Shortcut using PowerShell pointing to pythonw.exe
ps_shortcut_command = f"""
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut('{shortcut_path}')
$Shortcut.TargetPath = '{pythonw_exe}'
$Shortcut.Arguments = '"{run_py_path}"'
$Shortcut.WorkingDirectory = '{base_dir}'
$Shortcut.Description = 'Academic Research AI deep RAG tool'
$Shortcut.Save()
"""

try:
    subprocess.run(["powershell", "-Command", ps_shortcut_command], check=True)
    print(f"Successfully created Desktop Shortcut: {shortcut_path}")
except Exception as e:
    print(f"Error creating shortcut: {e}")
