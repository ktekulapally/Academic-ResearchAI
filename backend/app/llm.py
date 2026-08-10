import json
import httpx
import google.generativeai as genai
from .config import settings

# Initialize Gemini if configured
if settings.model_provider == "gemini":
    # Fallback to empty key or a warning if not set
    api_key = settings.gemini_api_key or "DUMMY_KEY"
    genai.configure(api_key=api_key)

def chat_json(prompt: str) -> dict:
    if settings.model_provider == "gemini":
        try:
            model = genai.GenerativeModel(
                model_name="gemini-3.5-flash",
                generation_config={"response_mime_type": "application/json"}
            )
            response = model.generate_content(prompt)
            # Sometimes LLMs wrap response in markdown blocks
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:]
            if text.endswith("```"):
                text = text[:-3]
            return json.loads(text.strip())
        except Exception as e:
            # Fallback warning
            print(f"Gemini API call failed, attempting Ollama fallback: {e}")
            
    # Ollama execution
    with httpx.Client(timeout=180) as client:
        response = client.post(
            f"{settings.ollama_base_url}/api/chat",
            json={
                "model": settings.ollama_chat_model,
                "stream": False,
                "format": "json",
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        response.raise_for_status()
        return json.loads(response.json()["message"]["content"])

def embed(text: str) -> list[float]:
    if settings.model_provider == "gemini":
        try:
            result = genai.embed_content(
                model="models/text-embedding-004",
                content=text,
                task_type="retrieval_document"
            )
            return result["embedding"]
        except Exception as e:
            print(f"Gemini Embedding failed, attempting Ollama fallback: {e}")

    # Ollama embedding execution
    with httpx.Client(timeout=120) as client:
        response = client.post(
            f"{settings.ollama_base_url}/api/embed",
            json={"model": settings.ollama_embed_model, "input": text},
        )
        if response.status_code >= 400:
            response = client.post(
                f"{settings.ollama_base_url}/api/embeddings",
                json={"model": settings.ollama_embed_model, "prompt": text},
            )
        response.raise_for_status()
        data = response.json()
        if "embeddings" in data:
            return data["embeddings"][0]
        return data["embedding"]

