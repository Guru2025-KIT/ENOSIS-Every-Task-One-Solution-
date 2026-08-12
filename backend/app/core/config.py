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

    # Document storage (Cloudinary). Left blank by default — every route
    # in api/routes/documents.py checks these are set before attempting
    # an upload, and returns a clear 503 instead of crashing if they're
    # not configured yet. Get these from your Cloudinary dashboard.
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # AI assistant (Groq — free tier, fast Llama inference). Same
    # "blank by default, clear 503 if unset" pattern as Cloudinary above.
    # Get a free key from console.groq.com.
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.1-8b-instant"

    # ElevenLabs
    ELEVENLABS_API_KEY: str = ""
    ELEVENLABS_VOICE_ID_FEMALE: str = "21m00Tcm4TlvDq8ikWAM"   # Rachel (default female)
    ELEVENLABS_VOICE_ID_MALE: str = "ErXwobaYiN019PkySvjV"     # Antoni (default male)


    # TEMPORARY testing convenience: when True, every logged-in faculty
    # member can manage/generate timetables, bypassing the
    # admin-or-delegated check entirely. The real permission system
    # (User.can_manage_timetable, require_timetable_manager,
    # POST/DELETE /users/{id}/timetable-access) still exists underneath
    # and is still tested — flip this to False once you're ready to
    # actually restrict who can generate. Defaults True so you can test
    # the full timetable flow immediately without an admin-delegation step.
    OPEN_TIMETABLE_ACCESS: bool = True


settings = Settings()
