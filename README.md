# Busca Semântica com pgvector

Este projeto demonstra como construir um sistema de busca semântica (RAG - Retrieval-Augmented Generation) utilizando **PostgreSQL** com a extensão **pgvector**, **LangChain**, e modelos de **OpenAI** ou **Google Gemini**.

## 🚀 Requisitos

- [Python 3.13+](https://www.python.org/)
- [Docker](https://www.docker.com/) e [Docker Compose](https://docs.docker.com/compose/)
- [uv](https://github.com/astral-sh/uv) (opcional, mas recomendado)
- [Make](https://www.gnu.org/software/make/) (opcional, para atalhos)

## 🛠️ Configuração

1. **Clone o repositório:**

    ```bash
    git clone https://github.com/higorrsc/fc-mba-challenges-semantic-search-pgvector.git
    cd fc-mba-challenges-semantic-search-pgvector
    ```

2. **Configure as variáveis de ambiente:**
    Copie o arquivo `.env.example` para `.env` e preencha com suas chaves de API:

    ```bash
    cp .env.example .env
    ```

    Ou

    ```bash
    copy .env.example .env
    ```

    Ou use o Makefile:

    ```bash
    make init-env
    ```

    *Nota: Você precisa de pelo menos uma chave de API (`OPENAI_API_KEY` ou `GOOGLE_API_KEY`) e configurar as demais variáveis do arquivo .env:*
    - *modelo a ser usado pelo OpenAI (`OPENAI_EMBEDDING_MODEL`) ou pelo Google (`GOOGLE_EMBEDDING_MODEL`) para processamento, é fornecido um modelo default para cada caso.*
    - *caminho do documento PDF (`PDF_PATH`) que deverá ser processado*
    - *configurar o `DATABASE_URL` (ex: `postgresql://postgres:postgres@localhost:5432/rag`)*
    - *configurar o nome da collection a ser criada/usada pelo PGVector (`PG_VECTOR_COLLECTION_NAME`).*

3. **Instale as dependências e prepare o ambiente:**

    ```bash
    make setup
    ```

## 🏃 Execução

Você pode executar o projeto passo a passo ou usando um único comando.

### Opção 1: Passo a Passo

1. **Inicie o banco de dados:**

    ```bash
    make start-db
    ```

2. **Ingestão de documentos:**
    Coloque o seu arquivo PDF no diretório raiz (padrão: `document.pdf`) e execute a ingestão:

    ```bash
    make ingest
    ```

3. **Inicie o Chat:**

    ```bash
    make chat
    ```

### Opção 2: Comando Único (Workflow Completo)

O comando abaixo inicia o banco, realiza o bootstrap da extensão `vector`, ingere os documentos, abre o chat e remove os containers ao final:

```bash
make cli
```

## 📂 Estrutura do Projeto

- `src/ingest.py`: Processa o PDF, divide em pedaços (chunks) e armazena os embeddings no pgvector.
- `src/search.py`: Contém a lógica de busca semântica.
- `src/chat.py`: Interface de linha de comando para interagir com os documentos.
- `src/config.py`: Gerenciamento de configurações e variáveis de ambiente.
- `compose.yaml`: Configuração do banco de dados PostgreSQL com pgvector.

## 🧹 Limpeza

Para parar e remover os containers do banco de dados:

```bash
make stop-db
```
