import os
from pathlib import Path
from dotenv import load_dotenv
import google.generativeai as genai

# Resolve root path and configure python path
base_dir = Path(__file__).resolve().parent.parent
os.environ["DATABASE_URL"] = f"sqlite:///{base_dir}/backend/academic_research.db"

load_dotenv(dotenv_path=base_dir / ".env", override=True)
api_key = os.getenv("GEMINI_API_KEY")

genai.configure(api_key=api_key)

try:
    print("Unfiltered Model List:")
    for m in genai.list_models():
        print(f"- {m.name} (Methods: {m.supported_generation_methods})")
except Exception as e:
    print(f"Error: {e}")
