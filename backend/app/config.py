import os
from dataclasses import dataclass
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables by resolving the path of the .env file in the workspace root
base_dir = Path(__file__).resolve().parent.parent.parent
env_path = base_dir / ".env"
load_dotenv(dotenv_path=env_path, override=True)



@dataclass(frozen=True)
class Settings:

    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./academic_research.db")
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    qdrant_url: str = os.getenv("QDRANT_URL", "http://localhost:6333")
    ollama_base_url: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    ollama_chat_model: str = os.getenv("OLLAMA_CHAT_MODEL", "qwen2.5:7b")
    ollama_embed_model: str = os.getenv("OLLAMA_EMBED_MODEL", "nomic-embed-text")
    model_provider: str = os.getenv("MODEL_PROVIDER", "ollama") # 'ollama' or 'gemini'
    gemini_api_key: str | None = os.getenv("GEMINI_API_KEY", None)
    searxng_url: str = os.getenv("SEARXNG_URL", "http://localhost:8080")
    openalex_url: str = os.getenv("OPENALEX_URL", "https://api.openalex.org")
    crossref_url: str = os.getenv("CROSSREF_URL", "https://api.crossref.org")
    grobid_url: str = os.getenv("GROBID_URL", "http://localhost:8070")
    minio_endpoint: str = os.getenv("MINIO_ENDPOINT", "localhost:9000")
    minio_access_key: str = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
    minio_secret_key: str = os.getenv("MINIO_SECRET_KEY", "minioadmin")
    minio_bucket: str = os.getenv("MINIO_BUCKET", "academic-documents")
    minio_secure: bool = os.getenv("MINIO_SECURE", "false").lower() == "true"
    tesseract_cmd: str = os.getenv("TESSERACT_CMD", r"C:\Program Files\Tesseract-OCR\tesseract.exe")
    jwt_secret_key: str = os.getenv("JWT_SECRET_KEY", "academic-research-ai-super-secret-key-2026")
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    papers_repo_dir: str = os.getenv("PAPERS_REPO_DIR", "d:/Develop/Academic-ResearchAI/papers_repository")

settings = Settings()
