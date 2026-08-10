import httpx
from .config import settings

def _get(url: str, params: dict) -> dict:
    with httpx.Client(timeout=30, follow_redirects=True) as client:
        response = client.get(url, params=params)
        response.raise_for_status()
        return response.json()

def search_openalex(query: str, limit: int = 8) -> list[dict]:
    data = _get(f"{settings.openalex_url}/works", {
        "search": query, "per-page": limit,
        "select": "id,display_name,doi,publication_year,authorships,primary_location,open_access,type"
    })
    out = []
    for w in data.get("results", []):
        loc = w.get("primary_location") or {}
        source = loc.get("source") or {}
        pdf_url = loc.get("pdf_url")
        if not pdf_url and w.get("open_access"):
            pdf_url = w["open_access"].get("oa_url")
        out.append({
            "source_type": "openalex",
            "title": w.get("display_name"),
            "url": pdf_url or loc.get("landing_page_url") or w.get("id"),
            "doi": w.get("doi"),
            "authors": [
                a.get("author", {}).get("display_name")
                for a in (w.get("authorships") or []) if a.get("author")
            ],
            "publication_year": w.get("publication_year"),
            "metadata": {"type": w.get("type"), "source": source.get("display_name")}
        })
    return out

def search_crossref(query: str, limit: int = 8) -> list[dict]:
    data = _get(f"{settings.crossref_url}/works", {
        "query.bibliographic": query, "rows": limit
    })
    out = []
    for w in data.get("message", {}).get("items", []):
        title = (w.get("title") or [None])[0]
        url = w.get("URL")
        year = None
        parts = w.get("published-print") or w.get("published-online") or w.get("issued")
        if parts and parts.get("date-parts"):
            year = parts["date-parts"][0][0]
        out.append({
            "source_type": "crossref",
            "title": title,
            "url": url,
            "doi": w.get("DOI"),
            "authors": [
                f"{a.get('given','')} {a.get('family','')}".strip()
                for a in w.get("author", [])
            ],
            "publication_year": year,
            "metadata": {"publisher": w.get("publisher"), "type": w.get("type")}
        })
    return out

def search_searxng(query: str, limit: int = 8) -> list[dict]:
    data = _get(f"{settings.searxng_url}/search", {"q": query, "format": "json"})
    return [{
        "source_type": "web",
        "title": r.get("title"),
        "url": r.get("url"),
        "doi": None,
        "authors": None,
        "publication_year": None,
        "metadata": {"engine": "searxng", "content": r.get("content")}
    } for r in data.get("results", [])[:limit]]
