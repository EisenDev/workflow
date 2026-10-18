---
name: orchestrate
description: Run the owner's multi-project agent workflow as lead from the workflow repo - take requests for one or more registered projects, ask priority, use the project's codemap to find the exact files, start Codex (build/debug/test/QA, local commits) and Gemini 4 Argon (writer, project docs from git) through Orca, review the diff with git, validate the docs, and push/merge only with the owner's OK. Use for /orchestrate, "project X has a bug / needs a feature / needs optimization", "map project X", "dry-run X", "continue", or "status of my projects".
---

# Orchestrate

Workflow repo `WF` = `$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow`. Run from there.
Details: `WF/taskflow.md` (steps), `WF/roles/claude-lead.md` (your role, review checklist),
`WF/profiles/<type>.md` (project rules), `WF/docs/orca.md` (commands).

## 0. Session start

```
WF/scripts/wf.sh list                         # projects + active tasks
WF/scripts/wf.sh writer-check                 # writer=gemini | writer=claude (you write)
WF/scripts/resource-gate.sh status            # memory
systemctl --user is-active wf-resource-watch  # if inactive: start it (docs/resources.md)
```

Orca safety floor: a wait timeout is a checkpoint; stop/retry/release a worker only with proof
(`worker-list` / `worker-show`). Unsure of a flag → `orca orchestration <cmd> --help`.
A task whose `task.md` is not "none" → continue it from its `Status:`.
Unknown project → ask path + type → `WF/scripts/wf.sh new <name> "<repo path>" <type>`.

## 1. Request → priority

One line per project: job + size (S tiny, no behaviour change | M normal | L split into M).
Ask **one** question: the priority order (suggest one). One active task per project.

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
`git grep <pat> <base>`), not the branch the owner has checked out. Status `building`.

## 4. Build (Codex)

```
orca orchestration run-create --objective "<name>: <job>" --json
orca worktree create --name tNNN-<slug> --repo path:"<repo path>" --base-branch <base> --json
WF/scripts/wf.sh prep <name> <worktree>
WF/scripts/resource-gate.sh wait agent
orca orchestration task-create --task-title "T-NNN <slug>" --spec "$(cat WF/projects/<name>/task.md)" --json
orca orchestration worker-start --task <task_id> --agent codex --worktree path:<worktree> --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

Record run/task/dispatch/worktree in `task.md`. Answer questions from the task or ask the owner.
`check` returns the oldest unacknowledged batch (often a heartbeat) until you `check --ack
<deliveryId>`: ack every batch you read. Timeout = checkpoint; after 3 empty waits use
`worker-list`. Codex: local commits only.

## 5. Check

`WF/scripts/wf.sh check <name> <worktree>` → PASS, or rework: 1–3 lines under `## Rework`,
then a new `task-create --task-title "T-NNN rework"` (spec: rework notes + task.md) and
`worker-start --task <new id> --agent codex --worktree path:<worktree>` (`--retry-of` only works
within the same Orca task). Back to 4. Two failed reworks → ask the owner.

## 6. Writer

writer=gemini (and size M/L):
```
orca orchestration task-create --task-title "T-NNN docs" --deps '["<build task_id>"]' \
  --spec "Writer for T-NNN. Follow the workflow-writer skill. Base branch: <base>. $(cat WF/projects/<name>/task.md)" --json
WF/scripts/resource-gate.sh wait agent
orca orchestration worker-start --task <docs task_id> --agent antigravity --worktree path:<worktree> --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
WF/scripts/wf.sh collect <name> <worktree>
```
`prep` already trusted the worktree for agy. Argon's quota = the **Gemini 4 Argon Weekly Limit** in agy's Models & Quota screen; the status bar's "AI: Out of credits" is paid overage credits and does **not** mean Argon is unavailable.
Gemini fails on model, Argon weekly limit or context, or writer=claude → you write `.wf/summary.md`,
`.wf/suggestions.md` and only the `## Docs` changes, then `collect`.

## 7. Verdict

`WF/scripts/wf.sh diff <name> <worktree>` → review with the role checklist (task match, bugs,
patterns, tests, profile rules, docs match the diff and `## Docs`). Docs wrong → back to the
writer; code wrong → back to Codex. Approve → report per project:

```
<project> — T-NNN <title>  [P1]
Done / Tests (check line) / Code review / Docs / Needs change before push / Suggestions / You check
OK to push?
```

Status `waiting-ok`; `worker-release` finished workers.

## 8. On the owner's OK

```
WF/scripts/wf.sh ship <name> <worktree>
orca worktree rm <worktree>
WF/scripts/wf.sh merge <name> <pr>
WF/scripts/wf.sh deploy <name>     # only if directory.md has deploy:, and only on the owner's OK
```
Update the codemap sections the task touched (incl. docs column), `wf.sh map-stamp <name>`.
Revise → step 4. Drop → `wf.sh archive <name> dropped` (ask before deleting branch/worktree).

## Rules

- Tokens: codemap first, exact files, `wf.sh diff` instead of raw diffs; short tasks; state in files.
- No push/merge/pull/deletion without the owner's OK. Workers only in task worktrees.
- Every worker start → `resource-gate.sh wait agent`; heavy commands → `resource-gate.sh run heavy --`.
- `worker-start` has no `--spec` in the installed Orca: always `task-create` first.
- `orca skills get` does not exist in the installed Orca (it opens the app window).
- First real runs: when an Orca command's output or flag differs from this skill, follow the
  real CLI (`--help`), finish the task, and tell the owner what to fix in the workflow.
