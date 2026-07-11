# PLEASE READ BEFORE REMOVING

**Rules:**

- **Schema changes**
  - Go through `supabase/migrations/` only — never edit live in the Supabase SQL editor.
  - If this PR includes a migration: RLS must be enabled + tested on any new user-owned table, and someone must run `supabase db push` after merge (no auto-deploy on our plan — note in the PR thread if pending).

- **Commit message** (PR title, since we squash-merge) must match one of:
  ```
  ^feat: .*$
  ^fix: .*$
  ^schema: .*$
  ^refactor: .*$
  ^test: .*$
  ^docs: .*$
  ^style: .*$
  ^chore: .*$
  ^perf: .*$
  ^ci: .*$
  ```
  MUST be a single line, MUST NOT end with a period/space/tab, MUST be ≤100 characters.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

**ATTENTION:** Migrations go straight to production on push, there's no preview database on our plan. Review carefully.

---
Thanks for reading, feel free to remove everything above this line and type what you need.

Solves: <issue number, if any>
Spec: <section reference, if relevant>