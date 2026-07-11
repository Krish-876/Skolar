# PLEASE READ BEFORE REMOVING

**Rules:**

- **Migration Requirement**
  - Schema changes go through `supabase/migrations/` only — never edit live in the Supabase SQL editor.
  - If relevant, reference the spec section: `Spec: #7`

- **Commit message** must match one of:
  ^schema: .*$
  ^fix: .*$
  ^feat: .*$
  ^chore: .*$
  ^docs: .*$
  ^test: .*$

  - Single line only, no trailing period/space, ≤100 characters

- **Post-merge**
  - If this PR includes a migration, run `supabase db push` after merge — auto-deploy is not active on our plan.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

**ATTENTION:** No preview database on our plan — migrations go straight to production on push. Review carefully.

---

## Summary


## Type
- [ ] Schema migration
- [ ] Code
- [ ] Docs/chore

## If migration: ran `supabase db push` after merge?
- [ ] Yes
- [ ] N/A

---
Feel free to remove everything above this line and describe your change below.
