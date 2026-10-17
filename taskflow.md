# Taskflow

How work goes from the owner's request to a merged PR, across several projects at once, with
**as few Claude tokens as possible**. Claude decides; Codex and Gemini do the reading and writing;
scripts do the bookkeeping.

`$WF` = this repo (`$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow`).
Orca commands: [docs/orca.md](docs/orca.md). Memory rules: [docs/resources.md](docs/resources.md).
Project-type rules: [profiles/](profiles/) (`unity.md`, `web.md`). `<base>` = `base:` in `directory.md`.

## Who does what

| Work | Who | Claude reads |
|---|---|---|
| Talk to owner, priorities, task, accept/rework, report | **Claude** (Opus 5.5, medium) | — |
| Read the codebase before a task (scout) | **Gemini** | `.wf/context.md`, ≤ 60 lines |
| Build, debug, test, QA (incl. Playwright) | **Codex** | nothing directly |
| Ownership + tests + diff size | **`wf.sh check`** | one line |
| Docs, summary, suggestions | **Gemini** | `summary.md`, `suggestions.md` |
| Archive, PR, merge, memory queue | **scripts** | one line |

Claude never opens the codebase or reads a full diff. If `summary.md` and the check line are not
enough to decide, Claude reads only the specific file/lines they point to.

## Files

Per project, in this repo (`projects/<name>/`, git-ignored):

| File | Contents | Written by |
|---|---|---|
| `directory.md` | local path, type, base branch, test command, files copied into worktrees | `wf.sh new`, owner |
| `task.md` | the one active task (template layout) | Claude |
| `archive.md` | finished tasks, newest first, with date/time | `wf.sh archive` |
| `summary.md` | what the last task did + project state; replaced every task/session | Gemini (via `wf.sh collect`) |
| `suggestions.md` | Gemini's suggestions; **empty** when there are none | Gemini (via `wf.sh collect`) |

Per task, in the worktree (`.wf/`, never committed): `context.md` (scout), `report.md` (Codex),
`summary.md` + `suggestions.md` (Gemini), `check.log`.

## Task sizes

| Size | When | Steps |
|---|---|---|
| **S** | typo, one-liner, obvious fix | task → build → check → report |
| **M** | normal feature/bug | full flow |
| **L** | big or unclear | Claude splits it into M tasks (scout first if needed) |

## The flow

### 0. Session start

```
$WF/scripts/wf.sh list                       # projects, active tasks, statuses
$WF/scripts/resource-gate.sh status          # memory; watcher must be active
orca status --json
```

### 1. Request → tasks

The owner may name several projects in one message. For each: find it in `wf.sh list`, restate
the job in one line, pick a size. **Ask the owner for priority** (P1 urgent / P2 normal / P3 when
free) in one combined question with a suggested order. One active task per project; more work for
the same project waits until the current task is archived.

### 2. Worktree + scout (M/L)

```
orca orchestration run-create --objective "<project>: <job>" --json
$WF/scripts/resource-gate.sh wait agent
orca orchestration worker-start --spec "<scout prompt>" --agent antigravity \
  --worktree new-top-level --repo path:<project path> --base-branch <base> --name tNNN-<slug> --json
$WF/scripts/wf.sh prep <name> <worktree>      # .wf/, copies .env.local etc. from directory.md
```

Scout prompt: "Read only what is needed for: <job>. Write `.wf/context.md`, max 60 lines: relevant
files with line ranges, how it works now, how to test it, risks. No code changes." For size S, skip
the scout and create the worktree with the build worker.

### 3. Task (Claude)

Write `projects/<name>/task.md` from the template, using `.wf/context.md`. Keep it 20–40 lines.
`## May edit` lists exact paths (dirs end with `/`): `wf.sh check` enforces it.

### 4. Build (Codex)

```
$WF/scripts/resource-gate.sh wait agent
orca orchestration task-create --task-title "T-NNN <slug>" --spec "$(cat projects/<name>/task.md)" --json
orca orchestration worker-start --task <task_id> --agent codex --worktree path:<worktree> --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

Codex builds, debugs, writes tests, runs them (heavy ones through the gate), does QA, commits, and
writes `.wf/report.md` (≤ 15 lines). Questions it sends: answer from the task or ask the owner.
A wait timeout is a checkpoint; after three empty waits, `worker-list` (see docs/orca.md).

### 5. Check (script)

```
$WF/scripts/wf.sh check <name> <worktree>
# PASS files=4 +120/-30 uncommitted=0 tests=ok
# FAIL ... tests=exit-8 log=... outside=src/x.cs
```

FAIL → rework: append 1–3 lines under `## Rework` in `task.md`, start Codex again with
`--retry-of <dispatch_id>`, back to step 4. Two failed reworks on the same point → ask the owner.

### 6. Docs, summary, suggestions (Gemini)

```
$WF/scripts/resource-gate.sh wait agent
orca orchestration worker-start --spec "<docs prompt>" --agent antigravity --worktree path:<worktree> --json
$WF/scripts/wf.sh collect <name> <worktree>
```

Gemini reads the task, `.wf/report.md` and the diff; updates the project's own docs (committed);
writes `.wf/summary.md` (what was done, whether it matches the task, tests, project state, open
items; ≤ 40 lines) and `.wf/suggestions.md` (only real suggestions, or leave it empty).
Size S: skip; Claude writes a 3-line summary from the report.

### 7. Review + report (Claude)

Read the check line, `summary.md`, `suggestions.md`. Look at code only where they point to a
problem. Tell the owner, per project, in a few lines:

- done / what changed (from the summary)
- tests: the check line
- needs change or revision before push (Claude's view + Gemini's suggestions)
- owner checks (visuals, feel) if any
- "OK to push?"

Set `Status: waiting-ok`. Release finished workers (`worker-release`).

### 8. Push and merge (only on the owner's OK)

```
$WF/scripts/wf.sh ship <name> <worktree>        # push branch + PR (summary.md as body)
orca worktree rm <worktree>                      # after the PR exists
$WF/scripts/wf.sh merge <name> <pr>              # squash-merge + archive as approved
```

"Revise" instead of OK → back to step 4 with notes. "Drop it" → `wf.sh archive <name> dropped`
(Claude asks before deleting the branch/worktree). Then the next queued request for that project
starts at step 2.

## Several projects at once

- Run one Orca Run per project; Claude waits on all of them with `check --wait`.
- Priority decides who starts first. Every worker start passes `resource-gate.sh wait agent`;
  every heavy command (Unity, Playwright, builds) passes `resource-gate.sh run heavy -- ...`, which
  runs one at a time. Lower priority simply waits longer.
- Reports to the owner are grouped per project in one message.

## Token rules for Claude

1. Never read source files or full diffs to "get context"; that is the scout's job.
2. Read only: `wf.sh` output, `summary.md`, `suggestions.md`, `.wf/context.md`, the task.
3. Keep task files short; point to files, never paste them.
4. Do not echo raw Orca JSON into thinking; extract the IDs and status.
5. State lives in files. A fresh session reads `wf.sh list` + the active `task.md`, nothing else.

## Rules

- Workers only run in task worktrees; never in the owner's main folder.
- Nothing is pushed or merged without the owner's OK.
- A worker that ran out of quota or login → task `Status: blocked`, tell the owner.

## To verify in the first real run

- Whether `worker-start --name` also names the git branch.
- How to select `gemini-4-argon-medium` for `--agent antigravity`.
- Whether `worker-start --spec` (create task + start in one call) works for the scout.
- `orca worktree rm` before `gh pr merge --delete-branch` (local branch in use otherwise).
