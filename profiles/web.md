# Profile: Web

Rules added to `taskflow.md` for web projects (Next.js, Node, Supabase). Codex follows them while
building and testing; Gemini flags violations in its summary; `wf.sh check` runs the tests.

## `projects/<name>/directory.md`

```
type: web
base: <branch tasks start from; usually main>
test: ~/workspace/Agent-Workflow/scripts/resource-gate.sh run heavy -- bash -c '{ test -d node_modules || npm ci --no-audit --no-fund; } && npm run typecheck && npm test'
copy: .env.local          # git-ignored local files a worktree needs; comma-separated
```

- A new worktree has no `node_modules`; the test command installs them once (`npm ci`, through
  the gate). The first check in a worktree is therefore slow.
- App in a subfolder (e.g. `web/`): `cd web && ...` inside the `bash -c` string, and
  `copy: web/.env.local`.
- Use the project's own package manager (lock file decides: `package-lock.json` → npm,
  `pnpm-lock.yaml` → pnpm).

## Never (any agent)

- Use `.env.production`, run any script ending in `:prod`, `db:push`, `db:link`, deploys
  (`vercel`, `netlify`), or migrations against a remote database.
- Run end-to-end tests that need a live or shared backend unless the task explicitly says so
  and names the isolated setup (e.g. tests that require `E2E_EMAIL_OUTBOX=true`).
- Print or commit anything from `.env*` files; `copy:` files stay untracked in the worktree.
- Change lock files without a dependency change in the task.

## Build, test, QA (Codex)

- Follow the project's own `AGENTS.md` / `CLAUDE.md` first; they know the codebase.
- Fast loop while building: typecheck + the unit tests near the change. Everything heavy
  (`next build`, Playwright, full test suites) through `resource-gate.sh run heavy -- ...`.
- New behaviour gets a unit test; UI flows get a Playwright test if the project has Playwright.
- QA: run the changed flow in Playwright headless (screenshots into `.wf/qa/` for the report) or a
  local dev server on a free port; stop the server afterwards. Never against production URLs.
- Database changes: a new migration file only; apply it to the local database only (`db:start`
  style scripts), and say so in the report.

## Gemini's summary must flag

1. Changes to lock files, env handling, auth, payments or database migrations.
2. New dependencies.
3. Any use of production scripts or env files.
4. Tests skipped, deleted or weakened.
