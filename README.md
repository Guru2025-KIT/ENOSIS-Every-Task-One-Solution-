# ENOSIS — Every Task. One Solution.

A unified faculty management platform. Flutter frontend (Android + Web),
FastAPI backend (MySQL + Google OR-Tools).

## Repo layout
```
enosis-platform/
  frontend/     Flutter app — see frontend/HOW_TO_RUN.md
  backend/      FastAPI + MySQL + OR-Tools — see backend/HOW_TO_RUN_BACKEND.md
  docs/
    DEV_DIARY.md                     Single running log of everything built, and why
    CONNECTING_FRONTEND_BACKEND.md   How to run both together
```

## Quick start
1. **Backend first:** `cd backend && docker compose up --build` (or see `backend/HOW_TO_RUN_BACKEND.md` for the no-Docker path)
2. **Frontend:** `cd frontend`, follow `frontend/HOW_TO_RUN.md` to generate the platform folders (`flutter create .`) and copy in the provided `lib/`/`pubspec.yaml`/`assets/`
3. **Connect them:** `docs/CONNECTING_FRONTEND_BACKEND.md` — base URL per platform, the Android cleartext-HTTP gotcha, and a full walkthrough of testing login + timetable generation end-to-end

## What's built so far
- **Auth** — signup, login, JWT, protected routes (backend), real login wired into the app (frontend)
- **Timetable** — Google OR-Tools CP-SAT constraint solver, Year(1-4)/Division(A-C) structure, college-branded colorful read-only view, and in-app generation for admins + delegated faculty coordinators
- Everything else (Attendance, Career Advancement, To-Do, CO-PO, AI Assistant) is scaffolded as clearly-labeled placeholders — see `docs/DEV_DIARY.md` for the full phase-by-phase history and reasoning behind every major decision.

## Read this first
`docs/DEV_DIARY.md` is the actual project history — what was built, which
packages were used and why, what broke and how it got fixed, and what's
still ahead. It's more useful than this README for understanding *why*
things are the way they are.
