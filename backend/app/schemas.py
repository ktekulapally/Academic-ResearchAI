from pydantic import BaseModel, Field

class ProjectCreate(BaseModel):
    name: str = Field(min_length=2, max_length=250)
    description: str | None = None

class QuestionCreate(BaseModel):
    question: str = Field(min_length=10, max_length=4000)

class ProjectOut(BaseModel):
    id: int
    name: str
    description: str | None

class QuestionOut(BaseModel):
    id: int
    project_id: int
    question: str
    refined_question: str | None

class ResearchRunOut(BaseModel):
    id: int
    question_id: int
    status: str
    query_count: int
    source_count: int
    evidence_count: int
    answer: str | None
    error: str | None
