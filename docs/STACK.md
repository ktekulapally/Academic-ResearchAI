# Technology Stack

## Core

| Concern | Technology | Reason |
|---|---|---|
| Client | Flutter | Web + Android + iOS path |
| API | FastAPI | Python-native API and AI integration |
| Orchestration | LangGraph | Stateful, inspectable research workflow |
| LLM runtime | Ollama | Local/private model execution |
| Embeddings | Ollama embedding model | Local semantic representation |
| Vector DB | Qdrant | Semantic retrieval and clustering |
| Relational DB | PostgreSQL | Durable research metadata |
| Search | SearXNG | Self-hosted general web search |
| Scholarly search | OpenAlex | Open scholarly discovery |
| Scholarly metadata | Crossref | DOI/citation metadata |
| PDF structure | GROBID | Scholarly PDF structure and references |
| Documents | Docling | Layout-aware document conversion |
| Object storage | MinIO | Self-hostable document storage |
| Cache/queue | Redis | Job and cache foundation |
| Containerization | Docker Compose | Reproducible local deployment |
| Observability | OpenTelemetry + Grafana | Planned |
| Optional workflows | n8n | Integration/scheduling, outside core |
| Optional AI lab | Flowise | Prompt/agent experiments, outside core |

## Architectural rule

The core product must remain functional without n8n or Flowise.

## Model-provider abstraction

All LLM/embedding calls go through `backend/app/llm.py` so the application can later support:

- Ollama
- hosted APIs
- institution-hosted models
- alternative open-weight runtimes

without changing the research graph.
