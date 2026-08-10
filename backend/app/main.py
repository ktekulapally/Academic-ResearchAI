from fastapi import FastAPI, BackgroundTasks, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from jose import JWTError, jwt
import bcrypt
from .db import init_db, SessionLocal
from .config import settings
from .models import (
    ResearchProject, ResearchQuestion, ResearchRun, Source, EvidenceItem,
    User, AcademicStandard, Stream, Subject, QuestionCluster, SourcePaper
)
from .schemas import ProjectCreate, ProjectOut, QuestionCreate, QuestionOut, ResearchRunOut
from .research_graph import run_research, run_exam_research

app = FastAPI(title="Academic Research AI", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# JWT & Password Configs
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)

def get_password_hash(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False


def create_access_token(data: dict) -> str:
    return jwt.encode(data, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)

def get_current_user(token: str = Depends(oauth2_scheme)):
    if not token:
        return None
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        return email
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

# Pydantic Schemas
class UserRegister(BaseModel):
    email: str
    password: str
    name: str

class UserLogin(BaseModel):
    email: str
    password: str

class FollowUpRequest(BaseModel):
    prompt: str

@app.on_event("startup")
def startup():
    init_db()

@app.get("/health")
def health():
    return {"status": "ok", "service": "academic-research-ai"}

# --- AUTH ENDPOINTS ---

@app.post("/api/v1/auth/register")
def register(payload: UserRegister):
    db = SessionLocal()
    user = db.query(User).filter(User.email == payload.email).first()
    if user:
        db.close()
        raise HTTPException(400, "Email already registered")
    hashed_pwd = get_password_hash(payload.password)
    user = User(email=payload.email, password_hash=hashed_pwd, name=payload.name)
    db.add(user)
    db.commit()
    db.close()
    return {"status": "success", "message": "User registered successfully"}

@app.post("/api/v1/auth/login")
def login(payload: UserLogin):
    db = SessionLocal()
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        db.close()
        raise HTTPException(401, "Invalid email or password")
    token = create_access_token({"sub": user.email})
    name = user.name
    db.close()
    return {"access_token": token, "token_type": "bearer", "name": name}

# --- DROPDOWNS & TAXONOMY ---

@app.get("/api/v1/standards")
def get_standards():
    db = SessionLocal()
    standards = db.query(AcademicStandard).order_by(AcademicStandard.level_order).all()
    res = [{"id": s.id, "name": s.name} for s in standards]
    db.close()
    return res

@app.get("/api/v1/standards/{standard_id}/streams")
def get_streams(standard_id: int):
    db = SessionLocal()
    streams = db.query(Stream).filter(Stream.standard_id == standard_id).all()
    res = [{"id": s.id, "name": s.name} for s in streams]
    db.close()
    return res

@app.get("/api/v1/streams/{stream_id}/subjects")
def get_subjects(stream_id: int):
    db = SessionLocal()
    subjects = db.query(Subject).filter(Subject.stream_id == stream_id).all()
    res = [{"id": s.id, "name": s.name} for s in subjects]
    db.close()
    return res

# --- EXAM RESEARCH TRIGGER & PROGRESS ---

@app.post("/api/v1/subjects/{subject_id}/deep-research")
def start_subject_research(subject_id: int, background_tasks: BackgroundTasks):
    db = SessionLocal()
    subject = db.get(Subject, subject_id)
    if not subject:
        db.close()
        raise HTTPException(404, "Subject not found")
        
    run = ResearchRun(
        question_id=1,  # mock linking question
        status="queued",
        answer="",
        error="Initialising deep analysis..."
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    
    # Trigger graph in background
    background_tasks.add_task(run_exam_research, run.id, subject_id)
    
    run_id = run.id
    db.close()
    return {"run_id": run_id, "status": "queued"}

@app.get("/api/v1/research-runs/{run_id}/progress")
def get_research_progress(run_id: int):
    db = SessionLocal()
    run = db.get(ResearchRun, run_id)
    if not run:
        db.close()
        raise HTTPException(404, "Research run not found")
    
    progress_logs = run.error or "Running..."
    res = {
        "run_id": run.id,
        "status": run.status,
        "progress": progress_logs.split("\n"),
        "answer": run.answer
    }
    db.close()
    return res

@app.get("/api/v1/subjects/{subject_id}/top-questions")
def get_top_questions(subject_id: int):
    db = SessionLocal()
    clusters = db.query(QuestionCluster).filter(QuestionCluster.subject_id == subject_id).order_by(
        QuestionCluster.frequency_count.desc()
    ).all()
    
    res = []
    for c in clusters:
        res.append({
            "id": c.id,
            "canonical_text": c.canonical_text,
            "frequency_count": c.frequency_count,
            "years_appeared": c.years_appeared,
            "solution_markdown": c.solution_markdown or "Solution is compiling in background. Please wait...",
            "concept_tags": c.concept_tags or []
        })
    db.close()
    return res

@app.post("/api/v1/questions/clusters/{cluster_id}/ask")
def ask_follow_up(cluster_id: int, payload: FollowUpRequest):
    db = SessionLocal()
    cluster = db.get(QuestionCluster, cluster_id)
    if not cluster:
        db.close()
        raise HTTPException(404, "Question cluster not found")
        
    from .llm import chat_json
    sol_prompt = (
        f"You are an academic tutor helping a student understand this exam question:\n"
        f"QUESTION: {cluster.canonical_text}\n"
        f"STANDARD SOLUTION:\n{cluster.solution_markdown}\n\n"
        f"The student is asking this follow-up question to clarify their understanding:\n"
        f"STUDENT QUERY: {payload.prompt}\n\n"
        f"Provide a clear, detailed, and helpful response. Use LaTeX notation for formulas if needed.\n"
        f"Return JSON with key 'response' containing your markdown text answer."
    )
    try:
        res_data = chat_json(sol_prompt)
        text_ans = res_data.get("response", "I'm sorry, I encountered an issue processing that follow-up.")
        db.close()
        return {"response": text_ans}
    except Exception as e:
        db.close()
        raise HTTPException(500, f"Error calling LLM: {e}")

# --- ORIGINAL PROJECT CRUD ENDPOINTS (For compatibility) ---

@app.post("/api/v1/projects", response_model=ProjectOut)
def create_project(payload: ProjectCreate):
    db = SessionLocal()
    project = ResearchProject(name=payload.name, description=payload.description)
    db.add(project)
    db.commit()
    db.refresh(project)
    result = ProjectOut(id=project.id, name=project.name, description=project.description)
    db.close()
    return result

@app.get("/api/v1/projects")
def list_projects():
    db = SessionLocal()
    rows = db.query(ResearchProject).order_by(ResearchProject.id.desc()).all()
    result = [{"id": x.id, "name": x.name, "description": x.description} for x in rows]
    db.close()
    return result

@app.post("/api/v1/projects/{project_id}/questions", response_model=QuestionOut)
def create_question(project_id: int, payload: QuestionCreate):
    db = SessionLocal()
    if not db.get(ResearchProject, project_id):
        db.close()
        raise HTTPException(404, "Project not found")
    q = ResearchQuestion(project_id=project_id, question=payload.question)
    db.add(q)
    db.commit()
    db.refresh(q)
    result = QuestionOut(
        id=q.id, project_id=q.project_id,
        question=q.question, refined_question=q.refined_question
    )
    db.close()
    return result

@app.get("/api/v1/projects/{project_id}/questions")
def list_questions(project_id: int):
    db = SessionLocal()
    rows = db.query(ResearchQuestion).filter(
        ResearchQuestion.project_id == project_id
    ).order_by(ResearchQuestion.id.desc()).all()
    result = [
        {"id": x.id, "project_id": x.project_id, "question": x.question,
         "refined_question": x.refined_question}
        for x in rows
    ]
    db.close()
    return result

@app.post("/api/v1/questions/{question_id}/research", response_model=ResearchRunOut)
def start_research(question_id: int, background_tasks: BackgroundTasks):
    db = SessionLocal()
    question = db.get(ResearchQuestion, question_id)
    if not question:
        db.close()
        raise HTTPException(404, "Research question not found")
    run = ResearchRun(question_id=question_id, status="queued")
    db.add(run)
    db.commit()
    db.refresh(run)
    background_tasks.add_task(run_research, run.id, question.id, question.question)
    result = ResearchRunOut(
        id=run.id, question_id=run.question_id, status=run.status,
        query_count=0, source_count=0, evidence_count=0,
        answer=None, error=None
    )
    db.close()
    return result

@app.get("/api/v1/research-runs/{run_id}", response_model=ResearchRunOut)
def get_run(run_id: int):
    db = SessionLocal()
    run = db.get(ResearchRun, run_id)
    if not run:
        db.close()
        raise HTTPException(404, "Research run not found")
    result = ResearchRunOut(
        id=run.id, question_id=run.question_id, status=run.status,
        query_count=run.query_count, source_count=run.source_count,
        evidence_count=run.evidence_count, answer=run.answer, error=run.error
    )
    db.close()
    return result

