# How to Run the ENOSIS Backend (Auth module)

This has been built AND tested already — 6/6 automated tests pass, and I
manually verified every endpoint against a real running server with curl.
You're not the first person to run this code; I already found and fixed two
real bugs (see `docs/DEV_DIARY_ENTRY_2026-08-08_auth.md`) before it got to you.

You have two ways to run it. Docker is the "real" way (matches production,
uses actual MySQL). The local/SQLite way is faster for quick iteration.

## Option A — Docker (recommended, real MySQL)

### Prerequisite
Docker Desktop installed and running (from the earlier setup guide).

### Steps
1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
   Then open `.env` and replace `JWT_SECRET_KEY` with a real random string:
   ```bash
   python3 -c "import secrets; print(secrets.token_hex(32))"
   ```
   Paste that value in as `JWT_SECRET_KEY`.

2. Start everything (MySQL + backend, one command):
   ```bash
   docker compose up --build
   ```
   First run takes a couple of minutes (downloading the MySQL image, installing
   Python packages). Wait for `Application startup complete.` in the logs.

3. Open **http://localhost:8000/docs** in a browser — this is FastAPI's
   auto-generated interactive API explorer. You can try `/auth/signup` and
   `/auth/login` directly from that page, no Postman needed.

4. To stop everything: `Ctrl+C`, then `docker compose down` (add `-v` if you
   also want to wipe the MySQL data volume and start fresh).

## Option B — Local Python, no Docker (SQLite, faster iteration)

### Prerequisite
Python 3.11+ installed.

### Steps
```bash
cd enosis-backend
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
This uses a local `enosis_dev.db` SQLite file automatically (no `.env` needed) —
see `app/core/config.py`. Same code, same API, just a different database
underneath. Open http://localhost:8000/docs same as above.

## Running the tests
```bash
pip install pytest httpx   # if not already installed
pytest
```
You should see `6 passed`. These run against their own isolated SQLite test
database (`test_enosis.db`), never your real dev data.

## Trying it with curl (if you don't want to use /docs)
```bash
# Sign up
curl -X POST http://localhost:8000/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"priya@enosis.edu.in","password":"secret123","full_name":"Dr. Priya Sharma"}'

# Log in (note: form data, not JSON — this is the OAuth2 password flow spec)
curl -X POST http://localhost:8000/auth/login \
  -d "username=priya@enosis.edu.in&password=secret123"
# copy the "access_token" value from the response, then:

# Call the protected route
curl http://localhost:8000/auth/me \
  -H "Authorization: Bearer PASTE_YOUR_TOKEN_HERE"
```

## What's real vs. still ahead
| Piece | Status |
|---|---|
| Signup, login, JWT issuing/verification | Done, tested |
| Password hashing (bcrypt) | Done |
| MySQL via Docker | Done |
| Protecting a route (`/auth/me`) | Done, tested |
| Flutter app actually calling this API | Not yet — still using the mock login. Next step. |
| Password reset / email verification | Not built — not asked for yet |
| Alembic migrations | Not yet — using `create_all()` while schema is still moving |

## What to send back to me
1. Did `docker compose up --build` work, or did you hit an error? (Send me the error text if so.)
2. Try signup + login from the `/docs` page — did it work?
3. Ready for me to wire this into the Flutter Login screen for real (Phase 20), or do you want to pick the next backend module first?
