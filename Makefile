.PHONY: help init-env setup venv install export-req export-req-dev start-db wait-db check-env check-ingest run-chat cli reset-db stop logs lint lint-fix type-check test doctor

# =========================
# Load environment variables
# =========================

ifneq (,$(wildcard .env))
include .env
export
endif

# =========================
# OS detection
# =========================

ifdef ComSpec
PYTHON_EXEC=$(VENV_DIR)/Scripts/python.exe
PIP_EXEC=$(VENV_DIR)/Scripts/pip.exe
COPY_CMD=copy .env.example .env
ENV_COPY_HINT=copy .env.example .env
else
PYTHON_EXEC=$(VENV_DIR)/bin/python
PIP_EXEC=$(VENV_DIR)/bin/pip
COPY_CMD=cp .env.example .env
ENV_COPY_HINT=cp .env.example .env
endif

# =========================
# Variables
# =========================

VENV_DIR ?= .venv

DB_SERVICE ?= postgres
DB_CONTAINER ?= postgres_rag
DB_NAME ?= rag
DB_USER ?= postgres

TABLE_NAME ?= $(PG_VECTOR_COLLECTION_NAME)

REQUIRED_ENV_VARS = \
GOOGLE_API_KEY \
GOOGLE_EMBEDDING_MODEL \
OPENAI_API_KEY \
OPENAI_MODEL \
DATABASE_URL \
PG_VECTOR_COLLECTION_NAME \
PDF_PATH

# =========================
# Detect uv
# =========================

HAS_UV := $(shell command -v uv 2>/dev/null || where uv 2>NUL)

# =========================
# Command Strategy
# =========================

ifneq ($(HAS_UV),)
RUN_PY=uv run python
RUN_TOOL=uv run
VENV_CREATE=uv venv $(VENV_DIR)
INSTALL_DEV=uv sync
else
RUN_PY=$(PYTHON_EXEC)
RUN_TOOL=$(PYTHON_EXEC) -m
VENV_CREATE=python -m venv $(VENV_DIR)
INSTALL_DEV=$(PIP_EXEC) install -e .
endif

# =========================
# Environment init
# =========================

init-env:
	@if [ -f .env ]; then \
		echo "✅ .env already exists"; \
	else \
		echo "📄 Creating .env from .env.example..."; \
		$(COPY_CMD); \
		echo "👉 Please edit the variables in .env"; \
	fi

# =========================
# Setup
# =========================

setup: init-env venv install
	@echo ""
	@echo "✅ Environment ready"

venv:
	@if [ ! -f "$(PYTHON_EXEC)" ]; then \
		echo "🔧 Creating virtual environment..."; \
		$(VENV_CREATE); \
	fi

install:
	@echo "📦 Installing dependencies..."
	$(INSTALL_DEV)

# =========================
# Export dependencies
# =========================

export-req:
	@echo "📄 Exporting production dependencies..."
ifneq ($(HAS_UV),)
	@uv export \
		--no-dev \
		--no-hashes \
		--no-annotate \
		--format requirements.txt \
		--output-file requirements.txt
else
	@$(PIP_EXEC) freeze > requirements.txt
endif
	@echo "✅ requirements.txt generated"

export-req-dev:
	@echo "📄 Exporting development dependencies..."
ifneq ($(HAS_UV),)
	@uv export \
		--no-hashes \
		--no-annotate \
		--format requirements.txt \
		--output-file requirements-dev.txt
else
	@$(PIP_EXEC) freeze > requirements-dev.txt
endif
	@echo "✅ requirements-dev.txt generated"


# =========================
# Environment validation
# =========================

check-env:
	@echo ""
	@echo "🔎 Checking environment configuration..."

	@if [ ! -f .env ]; then \
		echo ""; \
		echo "❌ .env file not found."; \
		echo "👉 Create it from the example file:"; \
		echo "   $(ENV_COPY_HINT)"; \
		echo ""; \
		exit 1; \
	fi

	@MISSING=0; \
	for VAR in $(REQUIRED_ENV_VARS); do \
		VAL=$$(eval echo \$$$${VAR}); \
		if [ -z "$$VAL" ]; then \
			echo "❌ $$VAR not set"; \
			MISSING=1; \
		fi; \
	done; \
	if [ $$MISSING -eq 1 ]; then \
		echo ""; \
		echo "❌ Missing required environment variables."; \
		echo "👉 Please configure your .env file."; \
		exit 1; \
	else \
		echo "✅ Environment variables OK"; \
	fi

# =========================
# Database
# =========================

start-db:
	@echo ""
	@echo "🚀 Starting database..."
	@docker compose up -d

wait-db:
	@echo ""
	@echo "⏳ Waiting database to become healthy..."
	@until [ "$$(docker inspect --format='{{.State.Health.Status}}' $$(docker compose ps -q $(DB_SERVICE)))" = "healthy" ]; do \
		sleep 2; \
	done
	@echo "✅ Postgres healthy"

reset-db:
	@echo "⚠️ Resetting database..."
	@docker compose down -v
	@docker compose up -d

stop:
	@echo "🛑 Stopping services..."
	@docker compose down

logs:
	@docker compose logs -f

# =========================
# Ingestion
# =========================

check-ingest:
	@echo ""
	@COUNT=$$(docker exec $(DB_CONTAINER) psql -U $(DB_USER) -d $(DB_NAME) -t -c "SELECT COUNT(*) FROM $(TABLE_NAME);" 2>/dev/null | tr -d ' '); \
	if [ "$$COUNT" = "" ]; then \
		echo "📄 Table not found. Running ingestion using $(PDF_PATH)..."; \
		$(RUN_PY) src/ingest.py; \
	elif [ "$$COUNT" = "0" ]; then \
		echo "📄 Database empty. Running ingestion..."; \
		$(RUN_PY) src/ingest.py; \
	else \
		echo "📄 Database already populated ($$COUNT records). Skipping ingestion."; \
	fi

# =========================
# Chat
# =========================

run-chat:
	@echo ""
	@echo "💬 Starting chat..."
	@$(RUN_PY) src/chat.py

# =========================
# CLI workflow
# =========================

cli: check-env start-db wait-db check-ingest run-chat

# =========================
# Quality
# =========================

lint:
	$(RUN_TOOL) ruff check .
	$(RUN_TOOL) ruff format --check .

lint-fix:
	$(RUN_TOOL) ruff check . --fix
	$(RUN_TOOL) ruff format .

type-check:
	$(RUN_TOOL) mypy .

test:
	$(RUN_TOOL) pytest -q

# =========================
# Diagnostics
# =========================

doctor:
	@echo "🩺 Running diagnostics..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker not installed"; exit 1; }
	@command -v python >/dev/null 2>&1 || { echo "❌ Python not installed"; exit 1; }
	@echo "✅ Docker and Python found"
	@if [ -n "$(HAS_UV)" ]; then \
		echo "⚡ uv detected"; \
	else \
		echo "ℹ️ uv not installed (fallback to pip)"; \
	fi

# =========================
# Help
# =========================

help:
	@echo ""
	@echo "Project commands"
	@echo ""
	@echo "Environment:"
	@echo "  make init-env      - Create .env from example"
	@echo "  make setup         - Create venv and install dependencies"
	@echo "  make export-req      - Export production dependencies"
	@echo "  make export-req-dev  - Export development dependencies
	@echo ""
	@echo "Development:"
	@echo "  make cli           - Start DB, ingest if needed, run chat"
	@echo ""
	@echo "Database:"
	@echo "  make reset-db      - Reset database (delete volumes)"
	@echo "  make stop          - Stop docker services"
	@echo "  make logs          - Show docker logs"
	@echo ""
	@echo "Quality:"
	@echo "  make lint          - Run Ruff checks"
	@echo "  make lint-fix      - Fix lint issues"
	@echo "  make type-check    - Run MyPy"
	@echo ""
	@echo "Tests:"
	@echo "  make test          - Run tests"
	@echo ""
	@echo "Diagnostics:"
	@echo "  make doctor        - Check system dependencies"
	@echo ""
