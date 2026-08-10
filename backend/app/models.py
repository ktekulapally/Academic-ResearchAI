from datetime import datetime
from sqlalchemy import String, Integer, DateTime, Text, ForeignKey, Float, JSON
from sqlalchemy.orm import Mapped, mapped_column
from .db import Base

class ResearchProject(Base):
    __tablename__ = "research_projects"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(250))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class ResearchQuestion(Base):
    __tablename__ = "research_questions"
    id: Mapped[int] = mapped_column(primary_key=True)
    project_id: Mapped[int] = mapped_column(ForeignKey("research_projects.id"))
    question: Mapped[str] = mapped_column(Text)
    refined_question: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class ResearchRun(Base):
    __tablename__ = "research_runs"
    id: Mapped[int] = mapped_column(primary_key=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("research_questions.id"))
    status: Mapped[str] = mapped_column(String(30), default="queued")
    query_count: Mapped[int] = mapped_column(Integer, default=0)
    source_count: Mapped[int] = mapped_column(Integer, default=0)
    evidence_count: Mapped[int] = mapped_column(Integer, default=0)
    answer: Mapped[str | None] = mapped_column(Text, nullable=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

class Source(Base):
    __tablename__ = "sources"
    id: Mapped[int] = mapped_column(primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("research_runs.id"))
    source_type: Mapped[str] = mapped_column(String(30))
    title: Mapped[str | None] = mapped_column(Text, nullable=True)
    url: Mapped[str] = mapped_column(Text)
    doi: Mapped[str | None] = mapped_column(String(250), nullable=True)
    authors: Mapped[list | None] = mapped_column(JSON, nullable=True)
    publication_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    relevance_score: Mapped[float] = mapped_column(Float, default=0.0)
    meta_info: Mapped[dict | None] = mapped_column(JSON, nullable=True)


class Document(Base):
    __tablename__ = "documents"
    id: Mapped[int] = mapped_column(primary_key=True)
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.id"))
    mime_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    object_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    extracted_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    parser: Mapped[str | None] = mapped_column(String(50), nullable=True)

class DocumentChunk(Base):
    __tablename__ = "document_chunks"
    id: Mapped[int] = mapped_column(primary_key=True)
    document_id: Mapped[int] = mapped_column(ForeignKey("documents.id"))
    chunk_index: Mapped[int] = mapped_column(Integer)
    text: Mapped[str] = mapped_column(Text)
    page_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    qdrant_point_id: Mapped[str | None] = mapped_column(String(100), nullable=True)

class EvidenceItem(Base):
    __tablename__ = "evidence_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("research_runs.id"))
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.id"))
    chunk_id: Mapped[int | None] = mapped_column(ForeignKey("document_chunks.id"), nullable=True)
    quote: Mapped[str | None] = mapped_column(Text, nullable=True)
    locator: Mapped[str | None] = mapped_column(String(250), nullable=True)
    relevance_score: Mapped[float] = mapped_column(Float, default=0.0)

class Claim(Base):
    __tablename__ = "claims"
    id: Mapped[int] = mapped_column(primary_key=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("research_runs.id"))
    claim: Mapped[str] = mapped_column(Text)
    confidence: Mapped[float] = mapped_column(Float, default=0.0)
    evidence_ids: Mapped[list | None] = mapped_column(JSON, nullable=True)

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(250), unique=True)
    password_hash: Mapped[str] = mapped_column(String(250))
    name: Mapped[str] = mapped_column(String(250))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class AcademicStandard(Base):
    __tablename__ = "academic_standards"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(250))
    level_order: Mapped[int] = mapped_column(Integer, default=0)

class Stream(Base):
    __tablename__ = "streams"
    id: Mapped[int] = mapped_column(primary_key=True)
    standard_id: Mapped[int] = mapped_column(ForeignKey("academic_standards.id"))
    name: Mapped[str] = mapped_column(String(250))

class Subject(Base):
    __tablename__ = "subjects"
    id: Mapped[int] = mapped_column(primary_key=True)
    stream_id: Mapped[int] = mapped_column(ForeignKey("streams.id"))
    name: Mapped[str] = mapped_column(String(250))

class SourcePaper(Base):
    __tablename__ = "source_papers"
    id: Mapped[int] = mapped_column(primary_key=True)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id"))
    file_path: Mapped[str] = mapped_column(Text)
    year: Mapped[int] = mapped_column(Integer)
    board_name: Mapped[str] = mapped_column(String(100))
    fetched_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class ExtractedQuestion(Base):
    __tablename__ = "extracted_questions"
    id: Mapped[int] = mapped_column(primary_key=True)
    source_paper_id: Mapped[int] = mapped_column(ForeignKey("source_papers.id"))
    raw_text: Mapped[str] = mapped_column(Text)
    question_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    topic_tag: Mapped[str | None] = mapped_column(String(100), nullable=True)
    qdrant_point_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    marks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latex_formulas: Mapped[list | None] = mapped_column(JSON, nullable=True)

class QuestionCluster(Base):
    __tablename__ = "question_clusters"
    id: Mapped[int] = mapped_column(primary_key=True)
    subject_id: Mapped[int] = mapped_column(ForeignKey("subjects.id"))
    canonical_text: Mapped[str] = mapped_column(Text)
    frequency_count: Mapped[int] = mapped_column(Integer, default=1)
    years_appeared: Mapped[list] = mapped_column(JSON, default=list)
    solution_markdown: Mapped[str | None] = mapped_column(Text, nullable=True)
    concept_tags: Mapped[list | None] = mapped_column(JSON, nullable=True)

class ClusterMembership(Base):
    __tablename__ = "cluster_membership"
    cluster_id: Mapped[int] = mapped_column(ForeignKey("question_clusters.id"), primary_key=True)
    question_id: Mapped[int] = mapped_column(ForeignKey("extracted_questions.id"), primary_key=True)
    similarity_score: Mapped[float] = mapped_column(Float, default=1.0)

