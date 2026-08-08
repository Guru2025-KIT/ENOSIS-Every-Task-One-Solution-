from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import StaticPool

from app.core.config import settings

# WHAT THIS DOES: creates the connection pool to the database. SQLAlchemy
# abstracts away SQL dialect differences, so the exact same model/query code
# below works whether DATABASE_URL points at local SQLite (fast to test
# with, no setup) or the real MySQL container (via Docker).
#
# SQLite-specific quirk: FastAPI runs each request's (sync) route handler in
# a worker thread, not the main thread. Plain SQLite connections are tied to
# the thread that created them, which causes spurious "readonly database" /
# locking errors under that pattern. check_same_thread=False plus StaticPool
# (reuse a single real connection instead of opening a new one per thread)
# is the standard fix — recommended directly in FastAPI's own SQLAlchemy
# tutorial. This branch only applies to SQLite; MySQL (via Docker) doesn't
# have this issue and uses a normal connection pool.
is_sqlite = settings.DATABASE_URL.startswith("sqlite")
connect_args = {"check_same_thread": False} if is_sqlite else {}
engine_kwargs = {"poolclass": StaticPool} if is_sqlite else {}

engine = create_engine(settings.DATABASE_URL, connect_args=connect_args, **engine_kwargs)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """
    A FastAPI "dependency" — declaring `db: Session = Depends(get_db)` on a
    route hands that route a fresh database session, and guarantees it gets
    closed afterward (even if the request raises an error), via this
    try/finally. This is the standard FastAPI + SQLAlchemy pattern.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
