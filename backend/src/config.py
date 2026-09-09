from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "Mountjoy Software Solutions API"
    API_V1_STR: str = "/api/v1"
    ENV: str = "local"
    APP_VERSION: str = "local-dev"
    PORT: int = 8000

    ANTHROPIC_API_KEY: str = ""
    CHAT_MODEL: str = "claude-sonnet-5"
    CHAT_MAX_TOKENS: int = 8000

    QDRANT_URL: str = "http://localhost:6333"
    QDRANT_API_KEY: str = ""
    EMBED_MODEL: str = "amazon.titan-embed-text-v2:0"
    EMBED_DIMENSIONS: int = 512
    GRAPH_EXPAND_LIMIT: int = 7
    RAG_CONTEXT_LIMIT: int = 6

    DDB_TABLE: str = "mss-portfolio"
    DDB_ENDPOINT: str = ""
    AWS_REGION: str = "us-east-1"

    CHAT_RATE_LIMIT: int = 5
    CHAT_RATE_WINDOW_SECONDS: int = 60
    CHAT_HOURLY_LIMIT: int = 40
    API_RATE_LIMIT: int = 60
    API_RATE_WINDOW_SECONDS: int = 60
    MAX_BODY_BYTES: int = 65536
    IP_HASH_SALT: str = "local-dev-salt"

    CORS_ORIGINS: list[str] = []

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
