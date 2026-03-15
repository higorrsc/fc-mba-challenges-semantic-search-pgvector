from pathlib import Path

from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """ "Default settings for the application"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Project Root
    PROJECT_ROOT: Path = Path(__file__).resolve().parents[1]

    # Google configuration
    GOOGLE_API_KEY: str | None = None
    GOOGLE_EMBEDDING_MODEL: str = "models/embedding-001"
    GOOGLE_LLM: str = "gemini-2.5-flash-lite"

    # OpenAI configuration
    OPENAI_API_KEY: str | None = None
    OPENAI_EMBEDDING_MODEL: str = "text-embedding-3-small"
    OPENAI_LLM: str = "gpt-5-nano"

    # Postgres and Vector configuration
    DATABASE_URL: str | None = None
    PG_VECTOR_COLLECTION_NAME: str = "documents"
    PG_VECTOR_DOCUMENTS_RESULT_LIMIT: int = 10

    # PDF configuration
    PDF_PATH: str = "document.pdf"

    # Chunk
    CHUNK_SIZE: int = 1000
    CHUNK_OVERLAP: int = 150

    @model_validator(mode="after")
    def validate_settings(self):
        """Ensure at least one LLM provider exists"""

        if not any([self.GOOGLE_API_KEY, self.OPENAI_API_KEY]):
            raise ValueError("No LLM provider configured")

        if not any([self.DATABASE_URL, self.PG_VECTOR_COLLECTION_NAME]):
            raise ValueError("No vector store configured")

        return self

    @property
    def pdf_file(self) -> Path:
        """Return absolute path to PDF file"""

        return (self.PROJECT_ROOT / self.PDF_PATH).resolve()

    @property
    def llm_provider(self) -> str:
        """Return preferred LLM provider (OpenAI first)"""

        return "openai" if self.OPENAI_API_KEY else "google"

    @property
    def llm_model(self) -> str:
        """Return preferred LLM model"""

        return self.OPENAI_LLM if self.llm_provider == "openai" else self.GOOGLE_LLM

    @property
    def embedding_model(self):
        """Return preferred embedding model instance"""

        return (
            OpenAIEmbeddings(model=self.OPENAI_EMBEDDING_MODEL)
            if self.llm_provider == "openai"
            else GoogleGenerativeAIEmbeddings(model=self.GOOGLE_EMBEDDING_MODEL)
        )

    @property
    def llm(self):
        """Return preferred LLM instance"""

        return (
            ChatOpenAI(
                model=self.llm_model,
                api_key=self.OPENAI_API_KEY,  # type: ignore
            )
            if self.llm_provider == "openai"
            else ChatGoogleGenerativeAI(
                model=self.llm_model,
                google_api_key=self.GOOGLE_API_KEY,
            )
        )


# Export settings
settings = Settings()
