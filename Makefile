.PHONY: help init-env setup venv install export-req export-req-dev lock check-env start-db stop-db logs ingest chat doctor

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
NULL_DEV = > NUL 2>&1
else
PYTHON_EXEC=$(VENV_DIR)/bin/python
PIP_EXEC=$(VENV_DIR)/bin/pip
COPY_CMD=cp .env.example .env
ENV_COPY_HINT=cp .env.example .env
NULL_DEV = > /dev/null 2>&1
endif

# =========================
# Variables
# =========================

VENV_DIR ?= .venv

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
	@echo ""
	@echo "📦 Installing dependencies..."
	$(INSTALL_DEV)

# =========================
# Export dependencies
# =========================

export-req:
	@echo ""
	@echo "📄 Exporting production dependencies..."
ifneq ($(HAS_UV),)
	@uv export \
		--no-dev \
		--no-hashes \
		--no-annotate \
		--format requirements.txt \
		--output-file requirements.txt \
		$(NULL_DEV)
else
	@$(PIP_EXEC) freeze > requirements.txt
endif
	@echo "✅ requirements.txt generated"

export-req-dev:
	@echo ""
	@echo "📄 Exporting development dependencies..."
ifneq ($(HAS_UV),)
	@uv export \
		--no-hashes \
		--no-annotate \
		--format requirements.txt \
		--output-file requirements-dev.txt \
		$(NULL_DEV)
else
	@$(PIP_EXEC) freeze > requirements-dev.txt
endif
	@echo "✅ requirements-dev.txt generated"

lock: export-req export-req-dev
	@echo ""
	@echo "🔒 Dependency lock complete"
	@echo "  - requirements.txt"
	@echo "  - requirements-dev.txt"


# =========================
# Environment validation
# =========================

check-env:
	@echo ""
	@echo "🔎 Checking environment configuration..."

	@if [ ! -f .env ]; then \
		echo ""; \
		echo "❌ .env file not found."; \
		echo "👉 Create it from the example file:";
		exit 1; \
	fi

# =========================
# Database
# =========================

start-db:
	@echo ""
	@echo "🚀 Starting database..."
	@docker compose up -d

stop-db:
	@echo "🛑 Stopping services..."
	@docker compose down

logs:
	@docker compose logs -f

# =========================
# Chat
# =========================

ingest:
	@echo ""
	@echo "📄 Ingesting documents..."
	@$(RUN_PY) -m src.ingest

chat:
	@echo ""
	@echo "💬 Starting chat..."
	@$(RUN_PY) -m src.chat

# =========================
# Chat
# =========================

cli: start-db ingest chat stop-db

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
	@echo "  make init-env        - Create .env from example"
	@echo "  make setup           - Create venv and install dependencies"
	@echo "  make export-req      - Export production dependencies"
	@echo "  make export-req-dev  - Export development dependencies"
	@echo "  make lock            - Generate both requirements files"
	@echo ""
	@echo "Chat:"
	@echo "  make ingest          - Ingest documents"
	@echo "  make chat            - Start chat"
	@echo ""
	@echo "Database:"
	@echo "  make start-db        - Start database"
	@echo "  make stop-db         - Stop docker services"
	@echo "  make logs            - Show docker logs"
	@echo ""
	@echo "Diagnostics:"
	@echo "  make doctor          - Check system dependencies"
	@echo ""
