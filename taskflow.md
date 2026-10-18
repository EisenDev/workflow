# Taskflow

How work goes from the owner's request to a merged PR, across several projects at once.
Quality first, tokens second: Claude reads **the code that matters** (the files it changes and the
task's diff) but never re-reads a whole codebase; a one-time **codemap** tells it where things are.

`$WF` = this repo (`$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow`).
Orca: [docs/orca.md](docs/orca.md). Memory: [docs/resources.md](docs/resources.md).
Project-type rules: [profiles/](profiles/). `<base>` = `base:` in `directory.md`.

## Who does what

| Work | Who |
|---|---|
| Codemap (one-time read, then updates for changed files only) | **Claude** |
| Priorities, finding the exact files, task, verdict, owner report | **Claude** (Opus 5.5, medium) |
| Build, debug, test, QA; **local commits only** | **Codex** |
| Ownership + tests in one line | **`wf.sh check`** |
| Docs, summary, suggestions, written from `git log` / `git diff` | **Gemini 4 Argon** (writer) — falls back to **Claude** |
| Validate Gemini's docs + read the task's diff with git → final verdict | **Claude** |
| Archive, PR, merge, memory queue | **scripts** |

## Files

Per project, in this repo (`projects/<name>/`, git-ignored):

| File | Contents | Written by |
|---|---|---|
| `directory.md` | path, type, base branch, test command, files copied into worktrees | `wf.sh new`, owner |
| `codemap.md` | structure, features → files, data, tests, conventions; `Mapped: <commit>` | Claude |
| `task.md` | the one active task | Claude |
| `archive.md` | finished tasks, newest first, with date/time | `wf.sh archive` |
| `summary.md` | last task + project state; replaced every task | Gemini (or Claude) |
| `suggestions.md` | suggestions; **empty** when there are none | Gemini (or Claude) |

Per task, in the worktree (`.wf/`, never committed): `report.md` (Codex), `summary.md` +
`suggestions.md` (writer), `check.log`.

## Task sizes

| Size | When | Steps |
|---|---|---|
| **S** | typo, one-liner, obvious fix, no behaviour change | task → build → check → diff → report (Claude writes the 3-line summary; no doc changes) |
| **M** | normal feature/bug | full flow |
| **L** | big or unclear | Claude splits it into M tasks |

## The flow

### 0. Session start

```
$WF/scripts/wf.sh list                       # projects, active tasks
$WF/scripts/wf.sh writer-check               # writer=gemini | writer=claude (reason)
$WF/scripts/resource-gate.sh status          # memory; watcher must be active
```

### 1. Request → tasks

The owner may name several projects in one message. For each: restate the job in one line, pick a
size, and **ask the owner for priority** in one combined question with a suggested order. One
active task per project.

### 2. Context: codemap first, never a full re-read

```
$WF/scripts/wf.sh map-status <name>
```

- `missing` → **one-time map**: Claude reads the repo structure (`git ls-files`, top-level docs,
  the project's `AGENTS.md`/`CLAUDE.md`, package/project files, entry points, one representative
  file per area, and the `docs/` index) and writes `codemap.md` from the template (100–250 lines),
  including which doc covers each feature and the project's doc convention. Then
  `wf.sh map-stamp <name>`. This is the only time Claude reads broadly.
- `stale` → it lists the files changed since the map. Claude reads only those that affect the
  map (new/moved/deleted modules, new features, changed entry points), updates the matching
  codemap sections, then `map-stamp`.
- `fresh` → continue.
- `behind N` vs origin → tell the owner the local base is behind; tasks would start from old code.
  Pull only with the owner's OK.

Then Claude uses the codemap to name the exact files and opens **only those** in the project
folder to understand the current code.

### 3. Task (Claude)

Write `projects/<name>/task.md` from the template, 20–40 lines, with an exact `## May edit`
(dirs end with `/`), file:symbol pointers in `## Notes` so Codex does not have to search (read them from `<base>`, e.g.
`git show <base>:<file>`, never from the branch the owner has checked out), and
`## Docs`: the project docs the writer should update (from the codemap's docs column), or
"none (why)".

### 4. Worktree + build (Codex)

```
orca orchestration run-create --objective "<name>: <job>" --json
orca worktree create --name tNNN-<slug> --repo path:<project path> --base-branch <base> --json
$WF/scripts/wf.sh prep <name> <worktree>
$WF/scripts/resource-gate.sh wait agent
orca orchestration task-create --task-title "T-NNN <slug>" --spec "$(cat projects/<name>/task.md)" --json
orca orchestration worker-start --task <task_id> --agent codex --worktree path:<worktree> --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

Codex builds, debugs, tests (heavy runs through the gate), does QA, makes **local commits only**
(`T-NNN: ...`, never push), and writes `.wf/report.md` (≤ 15 lines). A wait timeout is a
checkpoint; after three empty waits, `worker-list` (docs/orca.md). `check` keeps returning the oldest
unacknowledged batch (heartbeats included) until `check --ack <deliveryId>`: ack every batch read.

### 5. Check (script)

```
$WF/scripts/wf.sh check <name> <worktree>
# PASS files=4 +120/-30 uncommitted=0 tests=ok
```

FAIL → rework: 1–3 lines under `## Rework`, then a new Orca task "T-NNN rework" (spec = rework
notes + task.md) and `worker-start` on the same worktree (`--retry-of` only works within one task), back to
step 4. Two failed reworks on the same point → ask the owner.

### 6. Writer: docs, summary, suggestions

`writer=gemini` (from step 0):

```
orca orchestration task-create --task-title "T-NNN docs" --deps '["<build task_id>"]' \
  --spec "Writer for T-NNN. Follow the workflow-writer skill. Base branch: <base>. <task.md>" --json
$WF/scripts/resource-gate.sh wait agent
orca orchestration worker-start --task <docs task_id> --agent antigravity --worktree path:<worktree> --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
$WF/scripts/wf.sh collect <name> <worktree>
```

Gemini finds what changed with git (`git log --oneline <base>..HEAD`, `git diff <base>...HEAD`),
reads `.wf/report.md` and the task, and writes:

- **Project docs** (`docs/` in the project, shared with the other maintainer): reads only the
  docs index and the files in the task's `## Docs`; small edits to the affected sections in the
  project's convention; no task chatter; no restructuring; no new `docs/` folder. Committed
  locally on the task branch, so docs and code go in the same PR.
- `.wf/summary.md` (with a `Docs:` line) and `.wf/suggestions.md` (empty if none; includes other
  docs that are now out of date).

`wf.sh prep` adds the worktree to agy's `trustedWorkspaces` (agy trusts exact paths only).
Argon's quota = the **Gemini 4 Argon Weekly Limit** in agy's Models & Quota screen; the status bar's "AI: Out of credits" is paid overage credits and does **not** mean Argon is unavailable.

**Fallback to Claude** when `writer=claude`, or the Gemini worker fails/exits with a model error,
the Argon weekly limit at 0%, or a context-limit error: Claude writes the summary and suggestions itself (it reads the diff
in step 7 anyway) and only the doc changes the task really needs. Note "writer: claude (reason)"
in the report.

### 7. Validate + verdict (Claude, with git)

```
$WF/scripts/wf.sh diff <name> <worktree>     # commits, size, code diff without lock files/binaries
```

Claude reads the task's diff (the changed code, not the codebase) and Gemini's `summary.md`,
`suggestions.md` and doc changes, and checks: do the docs match the diff, were the docs in
`## Docs` (and the index, for a new doc) updated, and nothing else rewritten? Verdict:

- **revise** → rework notes, back to step 4 (code) or to the writer (docs only; Claude does not
  fix docs itself unless it is the writer fallback).
- **approve** → report to the owner, per project:

```
<project> — T-NNN <title>  [P1]
Done: <1–2 lines>
Tests: <check line>
Code review: <ok | issues fixed | open concerns>
Docs: <project docs updated | none needed (why)>
Needs change before push: <items, or "nothing">
Suggestions: <count + the important one, or "none">
You check: <visuals/feel, or "nothing">
OK to push?
```

Set `Status: waiting-ok`. Release finished workers (`worker-release`).

### 8. Push, merge, update the codemap (on the owner's OK)

```
$WF/scripts/wf.sh ship <name> <worktree>        # push branch + PR (summary.md as body)
orca worktree rm <worktree>
$WF/scripts/wf.sh merge <name> <pr>              # squash-merge + archive as approved
```

Then pull the merge into the local base only with the owner's OK (or leave it for the next
`map-status`), update the codemap sections the task touched, including new docs in the docs
column (Claude already read that diff), and `wf.sh map-stamp <name>`.

"Revise" → back to step 4. "Drop" → `wf.sh archive <name> dropped` (ask before deleting the
branch/worktree).

## Several projects at once

One Orca Run per project; Claude waits on all with `check --wait`. Priority decides who starts
first; every worker start passes `resource-gate.sh wait agent`, every heavy command passes
`resource-gate.sh run heavy -- ...` (one at a time). Reports are grouped per project.

## Token rules for Claude

1. Never re-read a whole codebase. Codemap first; then only the exact files and the task's diff.
2. Update the codemap from changed files only (`map-status` lists them).
3. Use `wf.sh diff` (lock files, `.meta`, binaries excluded) instead of raw `git diff`.
4. Keep task files short; point to file:symbol, never paste code.
5. Do not echo raw Orca JSON into thinking; extract IDs and status.
6. State lives in files: a fresh session reads `wf.sh list`, the active `task.md` and the codemap.

## Rules

- Workers only run in task worktrees; Codex and Gemini commit locally and never push.
- Nothing is pushed, pulled into the owner's folders, or merged without the owner's OK.
- A worker that ran out of quota or login → `Status: blocked`, tell the owner (writer: fall back).

## To verify in the first real run

- Verified (T-001 berry): `orca worktree create` → `~/orca/workspaces/<repo>/<name>`, branch
  `EisenDev/<name>`; check needs `--ack`; `--retry-of` is per task; agy needs a trusted path.
- Gemini worker failure shape when the Argon weekly limit is 0% or over context (to detect fallback).
- `orca worktree rm` before `gh pr merge --delete-branch` (local branch in use otherwise).
