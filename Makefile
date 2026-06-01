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
	counter/backend/.venv/bin/uvicorn app.main:app --reload --port 8001 --app-dir counter/backend

dev:
	@make -j2 server counter
