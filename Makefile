.PHONY: setup server counter dev sandbox sandbox-down sandbox-reset

PYTHON = python3

setup:
	$(PYTHON) -m venv server/.venv
	server/.venv/bin/pip install -r server/requirements.txt
	$(PYTHON) -m venv counter/backend/.venv
	counter/backend/.venv/bin/pip install -r counter/backend/requirements.txt

server:
	server/.venv/bin/uvicorn app.main:app --reload --port 8000 --app-dir server

counter:
	counter/backend/.venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8001 \
		--ssl-keyfile counter/backend/certs/key.pem \
		--ssl-certfile counter/backend/certs/cert.pem \
		--app-dir counter/backend

dev:
	@make server &
	@make counter

sandbox:
	docker compose -f sandbox/docker-compose.yml up -d
	@echo ""
	@echo "HAPI FHIR : http://localhost:9090/fhir"
	@echo "Launcher  : http://localhost:9091"
	@echo "FHIR base : http://localhost:9091/v/r4/fhir"

sandbox-down:
	docker compose -f sandbox/docker-compose.yml down

sandbox-reset:
	docker compose -f sandbox/docker-compose.yml down -v
	rm -f server/fhirpass.db
