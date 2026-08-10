import os
os.environ["DATABASE_URL"] = "sqlite:///./test_academic_research.db"

from fastapi.testclient import TestClient
from app.main import app
from app.db import init_db

# Ensure tables are created
init_db()

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"

def test_project_and_question():
    p = client.post("/api/v1/projects", json={
        "name": "Test Project",
        "description": "Testing"
    })
    assert p.status_code == 200
    project_id = p.json()["id"]

    q = client.post(
        f"/api/v1/projects/{project_id}/questions",
        json={"question": "How does AI affect student learning outcomes?"}
    )
    assert q.status_code == 200
    assert q.json()["project_id"] == project_id
