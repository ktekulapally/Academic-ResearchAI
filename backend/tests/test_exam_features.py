import os
os.environ["DATABASE_URL"] = "sqlite:///./test_academic_research.db"

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db import SessionLocal, init_db
from app.models import User, AcademicStandard, Stream, Subject, QuestionCluster

# Ensure tables are created
init_db()


client = TestClient(app)

@pytest.fixture(autouse=True)
def clean_db():
    # Clean up test database tables before tests
    db = SessionLocal()
    try:
        db.query(User).delete()
        db.query(QuestionCluster).delete()
        db.commit()
    except Exception:
        db.rollback()
    finally:
        db.close()

def test_auth_flow():
    # 1. Register
    reg_res = client.post("/api/v1/auth/register", json={
        "email": "student@example.com",
        "password": "securepassword123",
        "name": "Alex Student"
    })
    assert reg_res.status_code == 200
    assert reg_res.json()["status"] == "success"

    # 2. Login
    login_res = client.post("/api/v1/auth/login", json={
        "email": "student@example.com",
        "password": "securepassword123"
    })
    assert login_res.status_code == 200
    assert "access_token" in login_res.json()
    assert login_res.json()["name"] == "Alex Student"

    # 3. Invalid Login
    invalid_login = client.post("/api/v1/auth/login", json={
        "email": "student@example.com",
        "password": "wrongpassword"
    })
    assert invalid_login.status_code == 401

def test_taxonomy_dropdowns():
    # Standards
    std_res = client.get("/api/v1/standards")
    assert std_res.status_code == 200
    standards = std_res.json()
    assert len(standards) > 0
    std_id = standards[0]["id"]

    # Streams
    strm_res = client.get(f"/api/v1/standards/{std_id}/streams")
    assert strm_res.status_code == 200
    streams = strm_res.json()
    assert len(streams) > 0
    strm_id = streams[0]["id"]

    # Subjects
    sub_res = client.get(f"/api/v1/streams/{strm_id}/subjects")
    assert sub_res.status_code == 200
    subjects = sub_res.json()
    assert len(subjects) > 0

def test_trigger_deep_research():
    # Fetch a subject
    sub_res = client.get("/api/v1/standards")
    std_id = sub_res.json()[0]["id"]
    strm_res = client.get(f"/api/v1/standards/{std_id}/streams")
    strm_id = strm_res.json()[0]["id"]
    subjects = client.get(f"/api/v1/streams/{strm_id}/subjects").json()
    subject_id = subjects[0]["id"]

    # Trigger research
    research_res = client.post(f"/api/v1/subjects/{subject_id}/deep-research")
    assert research_res.status_code == 200
    data = research_res.json()
    assert "run_id" in data
    assert data["status"] == "queued"

    # Poll status
    run_id = data["run_id"]
    progress_res = client.get(f"/api/v1/research-runs/{run_id}/progress")
    assert progress_res.status_code == 200
    progress_data = progress_res.json()
    assert progress_data["run_id"] == run_id
    assert "status" in progress_data
    assert "progress" in progress_data
