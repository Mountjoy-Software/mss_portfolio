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

    DDB_TABLE: str = "mss-portfolio"
    DDB_ENDPOINT: str = ""
    AWS_REGION: str = "us-east-1"

    CHAT_RATE_LIMIT: int = 20
    CHAT_RATE_WINDOW_SECONDS: int = 3600
    IP_HASH_SALT: str = "local-dev-salt"

    CORS_ORIGINS: list[str] = []

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
