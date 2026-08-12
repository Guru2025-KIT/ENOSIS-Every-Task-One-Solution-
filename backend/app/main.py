from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, timetable, users, todo, documents, ai_assistant, notifications, achievements, voice
from app.core.config import settings
from app.db.base import Base, engine

# Importing every model module here (even though we don't use the names
# directly) is what makes Base.metadata.create_all() below actually know
# about these tables — SQLAlchemy only registers a model with Base once its
# module has been imported somewhere. Easy to forget when adding a new
# module's models; if a new table isn't showing up, check it's imported here.
from app.models import (  # noqa: F401
    user, academic, timetable as timetable_models, todo as todo_models,
    document, notification, achievement,
    schedule_config, constraints, generation_history,
)

# Creates tables if they don't already exist. Fine for this early stage of
# development; once the schema stabilizes across a few modules, we'll
# switch to Alembic migrations so schema changes are tracked and
# reversible instead of just "drop and recreate the table."
Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.APP_NAME)

# CORS: allows the Flutter web build (running on a different origin/port)
# to call this API from the browser. Wide open for now during development;
# tighten allow_origins to the real frontend URL(s) before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(timetable.router)
app.include_router(users.router)
app.include_router(todo.router)
app.include_router(documents.router)
app.include_router(ai_assistant.router)
app.include_router(notifications.router)
app.include_router(achievements.router)
app.include_router(voice.router)


@app.get("/health")
def health_check():
    """Simple liveness check — useful for Docker healthchecks and just
    confirming the server is up while you're developing."""
    return {"status": "ok", "app": settings.APP_NAME}
