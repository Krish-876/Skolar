# Bulk-create GitHub issues from the Skolar security review findings.
# Requires: GitHub CLI (gh) installed and authenticated (`gh auth login`),
# and run from inside the repo directory (D:\Projects\Skolar).

$issues = @(
    @{
        Title  = "[Security][Urgent] Add authentication to rag_llms FastAPI service"
        Labels = "security,urgent"
        Body   = @"
## Root cause
`lib/core/ai/rag_llms/main.py` exposes multiple routes with **no authentication**, all writing/reading directly against a service-role Supabase key that bypasses RLS.

## Findings this closes
- [ ] `/upload-pyq` — unauthenticated write into any college's question bank (`main.py:434`)
- [ ] `/upload-pyq` — client-controlled `uploaded_by` allows identity forgery (`pipeline.py:993`)
- [ ] `/questions`, `/stats` — unauthenticated cross-college enumeration / IDOR (`pipeline.py:880`, `main.py:184`)
- [ ] `/generate-batch`, `/generate-open-batch` — unauthenticated publish into live student feed (`pipeline.py:1377`)
- [ ] Prompt-injected PDF text poisons the question bank via unauthenticated upload (`pipeline.py:486`)

## Fix
Add an auth dependency (mirror `backend/app/dependencies.py`'s `get_current_user_id`) to every route in this service. Derive `college`, `uploaded_by`, `published_by` from the verified session instead of trusting client-supplied fields. Restrict CORS origins.
"@
    },
    @{
        Title  = "[Security][Urgent] Rotate leaked secrets and stop bundling .env in the app"
        Labels = "security,urgent"
        Body   = @"
## Root cause
`pubspec.yaml` declares the repo-root `.env` as a Flutter asset, bundling the Supabase **service-role** key and Groq API key into every compiled app build. Confirmed present in an actual build artifact (`build/app/.../flutter_assets/.env`) — these keys are already leaked.

## Findings this closes
- [ ] `pubspec.yaml:62` — service-role key + Groq key shipped in app bundle

## Fix
1. Rotate the Supabase service-role key and Groq API key immediately (dashboards, not git).
2. Remove `- .env` from `pubspec.yaml`'s `flutter.assets`.
3. Keep server-side secrets out of any directory referenced by the Flutter build.
"@
    },
    @{
        Title  = "[Security] Lock down solution-sheet upload path"
        Labels = "security"
        Body   = @"
## Root cause
`doc_type=solution` uploads let an unauthenticated/unverified caller overwrite an existing question's `model_answer` and mark it `answer_source: "professor"` — the highest-trust tier in the app — based only on an embedding-similarity match.

## Findings this closes
- [ ] Unauthenticated overwrite of professor model answers (`pipeline.py:624`)
- [ ] Prompt-injected solution text trusted verbatim (`pipeline.py:550`)

## Fix
Require a verified faculty/staff role before accepting `doc_type=solution` writes. Add a human review/approval step before persisting as `answer_source: professor`.
"@
    },
    @{
        Title  = "[Security] Fix RPC/service functions trusting client-supplied user_id"
        Labels = "security"
        Body   = @"
## Root cause
Several functions accept a `user_id`/`p_user_id` parameter directly from the caller instead of deriving it from the verified session (`auth.uid()`), relying entirely on callers behaving correctly.

## Findings this closes
- [ ] `get_nova_triggers()` — no internal ownership check (migration `20260713070423`)
- [ ] `handle_vote()` — lets any authenticated user forge votes as anyone (`baseline.sql:37`)
- [ ] `get_facts_snapshot()` — IDOR risk if ever exposed over network (`facts_service.py:206`)

## Fix
Derive the acting user via `auth.uid()` inside each function (as `save_onboarding_seed_context` already correctly does), or explicitly `RAISE EXCEPTION` when the supplied id doesn't match.
"@
    },
    @{
        Title  = "[Security] Clean up Supabase RLS policy debt"
        Labels = "security"
        Body   = @"
## Findings this closes
- [ ] Leftover `"dev read all questions"` policy grants full unauthenticated read access, defeating the properly-scoped authenticated policy next to it (`baseline.sql:1485`)
- [ ] Verify `backend/tests/test_rls.py`'s "anon" client isn't actually using a service-role key (would mean the RLS suite gives false coverage)

## Fix
Drop the dev-leftover permissive policy. Assert key type before use in tests/backend so a service-role key can never silently substitute for the anon key.
"@
    },
    @{
        Title  = "[Security] Remove production exposure of dev tooling (_DevMenu)"
        Labels = "security"
        Body   = @"
## Root cause
`_DevMenu` is the unconditional landing page (`/`) for every authenticated user in production — no `kDebugMode` guard, no role/onboarding check. Exposes the full internal route map and lets users skip onboarding.

## Findings this closes
- [ ] `app_routes.dart:54`

## Fix
Remove `_DevMenu` from the production route table (or gate behind `kDebugMode`/build flavor). Redirect `/` based on actual user state (onboarding complete → dashboard, etc.).
"@
    },
    @{
        Title  = "[Security][Low priority] Harden test/local dev hygiene"
        Labels = "security,low-priority"
        Body   = @"
## Findings this closes
- [ ] Hardcoded fallback test credentials in `test_rls.py` sent against the live Supabase project
- [ ] `supabase/.temp/` (pooler URL, project ref, org id) committed to git history
- [ ] SSRF in `download_papers.py` — unvalidated absolute URLs followed, no host pinning
- [ ] Dead/unwired `LoggingInterceptor` logs bearer tokens in cleartext (`dio_http_client.dart:87`)
- [ ] Decompression-bomb risk: unbounded `.docx`/image decoding (`pipeline.py:258`, `batch_upload.py:182`)
- [ ] LibreOffice `.doc` conversion has no explicit macro-safe-mode flag (`pipeline.py:308`)

## Fix
Batch these — none are currently exploitable over the network, but worth cleaning up. See recommendations in the full findings report for each.
"@
    }
)

foreach ($issue in $issues) {
    Write-Host "Creating issue: $($issue.Title)" -ForegroundColor Cyan
    gh issue create --title "$($issue.Title)" --body "$($issue.Body)" --label "$($issue.Labels)"
}

Write-Host "`nDone. Run 'gh issue list' to verify." -ForegroundColor Green
