---
name: orchestrate
description: Run the owner's agent workflow alone inside Antigravity (agy), whatever model is selected - one agent does every role (lead, codemap, task, build/debug/test/QA, check, docs writer, review, report) with no Orca workers, no Claude and no Codex. Take requests for one or more registered projects, ask priority, use the project's codemap, build in a task worktree with local commits, write the docs from git, self-review the diff, and push/merge/deploy only with the owner's OK. Use for /orchestrate, "project X has a bug / needs a feature / needs optimization", "map project X", "dry-run X", "continue", or "status of my projects".
---

# Orchestrate (solo, Antigravity)

You are the **only** agent. You do the lead's, the builder's and the writer's job yourself, in
order. Never start Orca workers, Claude, Codex or another agent.

Workflow repo `WF` = `$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow`. Run from there.
Rules per role (follow them all, they still apply when you play the role):
`WF/AGENTS.md`, `WF/taskflow.md` (steps), `WF/roles/claude-lead.md` (review checklist),
`WF/roles/codex-builder.md` (build rules), `WF/roles/gemini-writer.md` (docs/summary formats),
`WF/profiles/<type>.md` (project rules). The project's own `AGENTS.md` / `CLAUDE.md` come first.

## 0. Session start

```
WF/scripts/wf.sh list                         # projects + active tasks
WF/scripts/resource-gate.sh status            # memory
```

A task whose `task.md` is not "none" → continue it from its `Status:`.
Unknown project → ask path + type → `WF/scripts/wf.sh new <name> "<repo path>" <type>`.

## 1. Request → priority

One line per project: job + size (S tiny, no behaviour change | M normal | L split into M).
Ask **one** question: the priority order (suggest one). Then work the projects **one at a time**
in that order; one active task per project.

## 2. Codemap

`WF/scripts/wf.sh map-status <name>`
- `missing` → one-time map: `git ls-files`, top-level/project `AGENTS.md`/`CLAUDE.md`/README,
  package/project files, entry points, one file per area, the `docs/` index. Write
  `WF/projects/<name>/codemap.md` from the template (features → files → docs, docs convention),
  then `wf.sh map-stamp <name>`.
- `stale` → read only the listed changed files that matter, update the map, `map-stamp`.
- `behind N` vs origin → tell the owner; pull only with their OK.

Never re-read the whole codebase. From the map, open only the exact files to change.

## 3. Task

Write `WF/projects/<name>/task.md` (template layout, 20–40 lines): Goal, Change, exact
`## May edit` (dirs end with `/`), Acceptance, `## Docs` (from the map's docs column, or
"none (why)"), Notes with file:symbol pointers **read from `<base>`** (`git show <base>:<file>`,
`git grep <pat> <base>`), not the branch the owner has checked out. Leave the `Orca:` line as
`Orca: none (solo) worktree=<path>`. Status `building`.

## 4. Build (you, as builder)

```
git -C "<repo path>" fetch -q origin <base>        # read-only; no pull
git -C "<repo path>" worktree add -b tNNN-<slug> ~/.local/share/agent-workflow/worktrees/<name>/tNNN-<slug> origin/<base>
WF/scripts/wf.sh prep <name> <worktree>
```

Work **only** inside the worktree and only on `## May edit` paths. Follow
`roles/codex-builder.md`: bug → reproduce, root cause, then fix; new behaviour → failing test
first, then the smallest change that passes; no extra features or refactors. Fast loop:
typecheck + nearby tests. Heavy commands (builds, full suites, Playwright, `npm ci`) only through
`WF/scripts/resource-gate.sh run heavy -- <cmd>`. UI changes: check phone, tablet and desktop.
Commit locally (`T-NNN: <what>`), never push. Write `.wf/report.md` (max 15 lines): what changed,
tests run and result, anything unsure.

## 5. Check

`WF/scripts/wf.sh check <name> <worktree>` → PASS, or fix it yourself: add 1–3 lines under
`## Rework` in `task.md`, fix, commit, check again. Two failed reworks → stop and ask the owner.
A file outside `## May edit` → revert it, or ask the owner to widen the task; never edit the
list silently.

## 6. Writer (you, as writer; size M/L)

Switch hats: start from git, not from memory (`git log <base>..HEAD`, `git diff <base>...HEAD`,
`.wf/report.md`). Follow `roles/gemini-writer.md`: read only the project's docs index and the
`## Docs` files; small edits in the project's convention; no task chatter; never invent facts
(`TODO(owner): <question>`). Commit the docs locally. Write `.wf/summary.md` (max 40 lines, with a
`Docs:` line) and `.wf/suggestions.md` (one line per real suggestion, **empty when none**). Then
`WF/scripts/wf.sh collect <name> <worktree>`. Size S: summary only, no docs.

## 7. Verdict (you, as reviewer)

Review with fresh eyes, as if someone else wrote it: `WF/scripts/wf.sh diff <name> <worktree>`,
then the `roles/claude-lead.md` checklist (task match, bugs: edge cases/null/async/off-by-one,
project patterns, tests that would fail without the change, profile rules, docs match the diff and
`## Docs`). Found a problem → back to 4 (code) or 6 (docs); it counts as a rework. Then report per
project:

```
<project> — T-NNN <title>  [P1]
Done / Tests (check line) / Code review / Docs / Needs change before push / Suggestions / You check
OK to push?
```

Be honest about what you did not verify. Status `waiting-ok`. Next project in the priority order.

## 8. On the owner's OK

```
WF_PR_FOOTER="" WF/scripts/wf.sh ship <name> <worktree>   # no Claude attribution: you are not Claude
git -C "<repo path>" worktree remove <worktree>
WF/scripts/wf.sh merge <name> <pr>
WF/scripts/wf.sh deploy <name>     # only if directory.md has deploy:, and only on the owner's OK
```
Update the codemap sections the task touched (incl. docs column), `wf.sh map-stamp <name>`.
Revise → step 4. Drop → `wf.sh archive <name> dropped` (ask before deleting branch/worktree).

## Rules

- Single agent: no `orca orchestration`, no `claude`, no `codex`, no subagents. You play each
  role in turn, and the role's rules apply while you do.
- No push/merge/pull/deletion/deploy without the owner's OK. Edits only in task worktrees, plus
  `WF/projects/<name>/` state files.
- Heavy commands → `resource-gate.sh run heavy --`.
- Never print or commit secrets (`.env*`: list variable names only); no production DBs or
  `:prod` scripts unless the owner asks for that exact step.
- Tokens: codemap first, exact files, `wf.sh diff` instead of raw diffs; state lives in files, so
  a new session can "continue".
- When a command's real output differs from this skill, follow the real CLI (`--help`), finish
  the task, and tell the owner what to fix in the workflow.
