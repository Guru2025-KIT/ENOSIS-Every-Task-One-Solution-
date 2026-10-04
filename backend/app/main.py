from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, timetable, users, todo, documents, ai_assistant, notifications, achievements, voice, sli, sli_analytics, sli_integration, sli_ml, attendance, dashboard, copo, admin
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
    sli as sli_models,  # Student Learning Intelligence tables
    attendance as attendance_models,  # Lecture Attendance tables
)

# Creates tables if they don't already exist with retry logic so server doesn't crash
# if database container is still warming up.
import time
for attempt in range(1, 6):
    try:
        Base.metadata.create_all(bind=engine)
        from app.sync_and_seed import sync_database_schema, seed_admin_user, seed_all_faculty_profiles
        sync_database_schema()
        seed_admin_user()
        seed_all_faculty_profiles()
        print("Database schema synced & seeded successfully.")
        break
    except Exception as err:
        print(f"Database init attempt {attempt}/5 failed: {err}. Retrying in 2 seconds...")
        if attempt == 5:
            print("Warning: Database initialization failed after 5 attempts. Continuing server startup...")
        time.sleep(2)

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
# Alias /login and /signup at root for API compatibility
app.post("/login", response_model=auth.Token, tags=["auth"], include_in_schema=False)(auth.login)
app.post("/signup", response_model=auth.UserOut, status_code=201, tags=["auth"], include_in_schema=False)(auth.signup)
app.include_router(timetable.router)
app.include_router(users.router)
app.include_router(todo.router)
app.include_router(documents.router)
app.include_router(ai_assistant.router)
app.include_router(notifications.router)
app.include_router(achievements.router)
app.include_router(voice.router)
app.include_router(sli.router)
app.include_router(sli_analytics.router)
app.include_router(sli_integration.router)
app.include_router(sli_ml.router)
app.include_router(attendance.router)
app.include_router(dashboard.router)
app.include_router(copo.router)
app.include_router(admin.router)


@app.get("/")
def root():
    return {
        "app": settings.APP_NAME,
        "status": "online",
        "documentation": "/docs",
        "health": "/health",
    }


@app.get("/health")
def health_check():
    """Simple liveness check — useful for Docker healthchecks and just
    confirming the server is up while you're developing."""
    return {"status": "ok", "app": settings.APP_NAME}
