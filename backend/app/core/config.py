from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Central app configuration, loaded from environment variables (see .env.example).

    WHY THIS EXISTS: secrets (DB password, JWT signing key) must never be
    hardcoded in source code — that's the security rule from day one of this
    project. Pydantic reads them from environment variables / a .env file
    instead. In Docker, docker-compose.yml injects these as real env vars;
    locally, a .env file (which is gitignored) does the same job.
    """

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database — defaults to a local SQLite file so you can run/test the API
    # without Docker running. docker-compose.yml overrides this to point at
    # the real MySQL container.
    DATABASE_URL: str = "sqlite:///./enosis_dev.db"

    # JWT
    JWT_SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours

    # App
    APP_NAME: str = "ENOSIS Backend"
    ENV: str = "development"

    # Displayed on the timetable and other institution-branded screens.
    # Override in .env — this default is a clearly-fake placeholder so
    # nobody accidentally ships it.
    COLLEGE_NAME: str = "Your College Name Here"


settings = Settings()
