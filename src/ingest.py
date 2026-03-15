from pathlib import Path

from langchain_community.document_loaders import PyPDFLoader
from langchain_core.documents import Document
from langchain_postgres import PGVector
from langchain_text_splitters import RecursiveCharacterTextSplitter

from .config import settings


def load_pdf(file_path: Path) -> list[Document]:
    """Load PDF file content"""

    if not file_path.exists():
        raise FileNotFoundError(f"PDF file not found: {file_path}")

    loader = PyPDFLoader(file_path)
    return loader.load()


def split_documents(documents: list[Document]) -> list[Document]:
    """Split documents into chunks"""

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=settings.CHUNK_SIZE,
        chunk_overlap=settings.CHUNK_OVERLAP,
        add_start_index=False,
    )

    splits = splitter.split_documents(documents)

    return [
        Document(
            page_content=split.page_content,
            metadata={k: v for k, v in split.metadata.items() if v not in ("", None)},
        )
        for split in splits
    ]


def build_vector_store() -> PGVector:
    """Build vector store"""

    return PGVector(
        embeddings=settings.embedding_model,
        collection_name=settings.PG_VECTOR_COLLECTION_NAME,
        connection=settings.DATABASE_URL,
        use_jsonb=True,
    )


def generate_ids(count: int) -> list[str]:
    """Generate document IDs"""

    return [f"doc_{i}" for i in range(count)]


def ingest_pdf() -> None:
    """Ingest PDF file into vector store"""

    documents = load_pdf(settings.pdf_file)
    chunks = split_documents(documents)

    if not chunks:
        raise RuntimeError("No chunks generated from PDF file")

    ids = generate_ids(len(chunks))

    store = build_vector_store()
    store.add_documents(documents=chunks, ids=ids)

    print(f"Successfully indexed {len(chunks)} chunks.")


def main() -> None:
    """Main entrypoint"""

    ingest_pdf()


if __name__ == "__main__":
    main()
