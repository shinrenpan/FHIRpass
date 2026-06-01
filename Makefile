.PHONY: setup server counter dev

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
