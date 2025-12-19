# Convenience targets for local development
.PHONY: up migrate test down

up:
	@echo "Starting services (use Ctrl+C to stop)..."
	docker compose up

migrate:
	@echo "Running migrations against local compose Postgres..."
	docker compose up --abort-on-container-exit --exit-code-from migrate

migrate-clean:
	@echo "Cleaning volumes and running migrations (destructive)..."
	docker compose down -v
	docker compose up --abort-on-container-exit --exit-code-from migrate

migrate-clean:
	@echo "Removing compose volumes and running a clean migration..."
	docker compose down -v
	docker compose up --abort-on-container-exit --exit-code-from migrate

test: migrate
	@echo "Tests executed as part of migration run"

down:
	docker compose down
