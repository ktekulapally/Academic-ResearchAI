import os
import sys
from pathlib import Path

# Resolve root path and configure python path
base_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(base_dir / "backend"))

os.environ["DATABASE_URL"] = f"sqlite:///{base_dir}/backend/academic_research.db"

from app.db import SessionLocal, init_db
from app.research_graph import run_exam_research
from app.models import Subject, ResearchRun

init_db()
db = SessionLocal()
try:
    # Fetch Intermediate Board Physics subject (ID: 7)
    sub = db.query(Subject).filter(Subject.id == 7).first()
    if not sub:
        print("Subject ID 7 not found. Did database seed run?")
        exit(1)

    print(f"Creating a new ResearchRun in database for subject: {sub.name} (ID: {sub.id})...")
    run = ResearchRun(
        question_id=1,  # Mock linking question ID
        status="queued",
        answer="",
        error="Initializing local test..."
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    
    print(f"Executing Deep Research pipeline for Run ID: {run.id}...")
    run_exam_research(run_id=run.id, subject_id=sub.id)
    
    # Reload run to see final state
    db.refresh(run)
    print(f"\nPipeline finished with status: {run.status}")
    print(f"Logs:\n{run.error}")
except Exception as e:
    import traceback
    print("\n[ERROR] Test runner script failed:")
    traceback.print_exc()
finally:
    db.close()
