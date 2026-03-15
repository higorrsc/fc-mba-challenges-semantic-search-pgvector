from typing import Callable

from langchain_core.documents import Document
from langchain_core.prompts import PromptTemplate
from langchain_postgres import PGVector

from .config import settings
from .ingest import build_vector_store

PROMPT_TEMPLATE = """
CONTEXTO:
{contexto}

REGRAS:
- Responda somente com base no CONTEXTO.
- Se a informação não estiver explicitamente no CONTEXTO, responda:
  "Não tenho informações necessárias para responder sua pergunta."
- Nunca invente ou use conhecimento externo.
- Nunca produza opiniões ou interpretações além do que está escrito.

EXEMPLOS DE PERGUNTAS FORA DO CONTEXTO:
Pergunta: "Qual é a capital da França?"
Resposta: "Não tenho informações necessárias para responder sua pergunta."

Pergunta: "Quantos clientes temos em 2024?"
Resposta: "Não tenho informações necessárias para responder sua pergunta."

Pergunta: "Você acha isso bom ou ruim?"
Resposta: "Não tenho informações necessárias para responder sua pergunta."

PERGUNTA DO USUÁRIO:
{pergunta}

RESPONDA A "PERGUNTA DO USUÁRIO"
"""


def similarity_search(
    store: PGVector,
    query: str,
    k: int = settings.PG_VECTOR_DOCUMENTS_RESULT_LIMIT,
) -> list[tuple[Document, float]]:
    """Perform a similarity search on the vector store"""

    return store.similarity_search_with_score(query, k=k)


def search_prompt(
    k: int = settings.PG_VECTOR_DOCUMENTS_RESULT_LIMIT,
) -> Callable[[str], str]:
    """
    Instantiate the search chain and return a callable that takes a question
    and returns an answer based on the context retrieved.
    """

    store = build_vector_store()
    prompt_template = PromptTemplate.from_template(PROMPT_TEMPLATE)
    llm = settings.llm
    chain = prompt_template | llm

    def ask_question(question: str) -> str:
        if not question:
            return "Por favor, forneça uma pergunta."

        results = similarity_search(store, question, k=k)

        if not results:
            return "Não foi possível encontrar documentos relevantes para sua pergunta."

        context = "\n\n---\n\n".join([doc.page_content for doc, _ in results])
        response = chain.invoke({"contexto": context, "pergunta": question})

        return getattr(response, "content", str(response))

    return ask_question


def main() -> None:
    """Main entrypoint"""


if __name__ == "__main__":
    main()
