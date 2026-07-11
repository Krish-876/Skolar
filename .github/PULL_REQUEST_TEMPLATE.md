# PLEASE READ BEFORE REMOVING

**Rules:**

- Schema changes go through `supabase/migrations/` only — never edit live in the Supabase SQL editor.
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

  Single line, no trailing period/space, ≤100 characters. Individual commits on your branch don't need to match — only the squashed PR title does.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.

---

## Summary


## Type
- [ ] Schema migration
- [ ] Code
- [ ] Docs/chore

<details>
<summary>Schema migration checklist (expand if this PR touches supabase/migrations/)</summary>

**No preview database on our plan — migrations go straight to production on push. Review carefully.**

- [ ] Reference the spec section if relevant: `Spec: #`
- [ ] RLS enabled on any new user-owned table
- [ ] Policy written in this same PR
- [ ] Tested against a non-owner session (service role bypasses RLS and hides bugs)
- [ ] Ran `supabase db push` after merge, OR noted as pending in PR thread

</details>

---
Feel free to remove everything above this line and describe your change below.