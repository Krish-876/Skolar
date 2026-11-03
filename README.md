# Skolar

An AI-powered exam preparation platform built with Flutter. Helps students
track syllabus progress, attempt mock tests, get AI-driven predictions, and
visualize their performance — all in one place. Authentication through
college email ensures secure, college-specific access to resources and data
isolation.

Personalized mock tests are calibrated to a student's college difficulty
level using Diverse In-Context Learning (DICL) over the college's own PYQs.
Nova, an AI mentor, reasons over a fresh daily facts snapshot (exam urgency,
weakness type, capacity, career relevance, history) to tell a student where
to put their hours — with no hardcoded priority rules.

---

## Documentation Map

This README is a short entry point. Full reference docs:

| Doc | Covers |
|---|---|
| [FLUTTER.md](FLUTTER.md) | Clean Architecture, folder structure, tech stack, running/codegen, every feature (Mock Tests, Exam Prediction, Focus Session, Community Feed, Subjects, Profile, Dashboard, Math Game, Auth) |
| [BACKEND.md](BACKEND.md) | The three backend services, ports, run commands, the DICL question-generation pipeline, PYQ batch upload tooling, RLS test running, CI |
| [NOVA.md](NOVA.md) | Nova's API service, the proposals confirmation-gate flow, the chat UI, the CLI prototype, the trigger layer, Nova's own schema |
| [DATABASE.md](DATABASE.md) | Core Supabase schema, cascade behavior, storage, RLS conventions, migrations |
| [`backend/pyq/ONBOARDING.md`](backend/pyq/ONBOARDING.md) | File-by-file map and setup for the question-generation pipeline codebase specifically — read this before touching `backend/pyq/rag/` |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Deep dive on the Clean Architecture principles referenced above |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Contribution guidelines |

Each doc above cross-links to the others where relevant — start wherever
matches what you're touching.

---

## Quick Start

**Flutter app:**

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

**Backend** — there are three separate services; run whichever you need
(see [BACKEND.md](BACKEND.md) and [NOVA.md](NOVA.md) for full detail, env
vars, and `--host 0.0.0.0` guidance for physical-device testing):

```bash
cd backend
pip install -r requirements.txt          # pyq/rag pipeline
uvicorn pyq.rag.main:app --reload --port 8000

pip install -r nova/requirements.txt     # Nova API (chat, facts, reasoning, proposals)
uvicorn nova.api.main:app --reload --port 8080

uvicorn app.main:app --reload --port 8001   # Nova trigger-check
```

`Environment.development.apiBaseUrl` in `lib/core/config/environment.dart`
points at `http://localhost:8080` (the Nova API) by default.

---

## Status Snapshot

**Built:** magic-link + password + Google auth (Supabase Auth), onboarding
with a single seed-context RPC, mock test platform (4 exam types), exam
prediction / question bank browser, focus session (Pomodoro), community
feed, subjects + handout upload + study plan generation, math game, dashboard
UI (dummy data — real Nova-backed data is stubbed, not wired), Nova chat UI
with proposal confirmation cards, Nova API service (chat/facts/reasoning/proposals
— unauthenticated, see [NOVA.md](NOVA.md#auth--the-real-gap)), Nova
trigger-check service (authenticated), PYQ batch upload tooling, RLS
isolation test suite.

**In review, not merged:** AI-assisted subject matching — see
[NOVA.md](NOVA.md#ai-subject-matching-in-review-not-merged).

**Schema live, no UI/code yet:** `test_attempts` / `question_results` /
`ai_evaluations` (test attempt flow), most of [Nova — Still To Build](NOVA.md#nova--still-to-build).

**Known gaps worth knowing before you build on top of something:** Nova's
API has no auth on any route yet ([NOVA.md](NOVA.md#tech-debt)); Compre Part
A results never reach the community feed
([FLUTTER.md](FLUTTER.md#tech-debt)); `/extract-plan` isn't a real FastAPI
route, it's a Supabase Edge Function
([BACKEND.md](BACKEND.md#post-extract-plan--not-a-fastapi-route)). Full
tech-debt lists live at the bottom of each linked doc.

---

## Roadmap (condensed)

```
Phase 1 — Foundation (complete)
Phase 2 — AI Pipeline (complete): DICL question generation, FastAPI backend, Supabase, Railway
Phase 3 — Core Features (complete): mock tests, exam prediction, feed, focus session
Phase 4 — Auth and Backend (complete): auth, onboarding, subjects, Nova schema foundations,
    Nova CLI prototype, RLS test suite, PYQ batch upload
Phase 5 — Personalisation (in progress):
    ✅ Nova chat UI + reasoning endpoint + proposals confirmation-gate flow
    ⬜ Nova auth (blocks shipping the chat UI to real users — see NOVA.md)
    ⬜ Study plan display UI, test_attempts/question_results/ai_evaluations wired into the app
    ⬜ Trigger layer called from anywhere (currently live but unused)
Phase 6 — ML Extension (planned): full top-15→MMR DICL, fine-tuning experiments
```

---

*Built by Krishna — BITS Pilani Hyderabad, B.Tech CSE 2024–2028*
