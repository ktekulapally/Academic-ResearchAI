import subprocess
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
    shell=True,
    creationflags=0x08000000 # CREATE_NO_WINDOW
)
