up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f api

test:
	docker compose run --rm api pytest -q

pull-models:
	docker exec -it academic-research-ai-ollama ollama pull qwen2.5:7b
	docker exec -it academic-research-ai-ollama ollama pull nomic-embed-text
