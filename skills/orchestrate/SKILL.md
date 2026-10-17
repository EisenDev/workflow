---
name: orchestrate
description: Run the owner's multi-project agent workflow as lead from the workflow repo - take requests for one or more registered projects, ask priority, use the project's codemap to find the exact files, start Codex (build/debug/test/QA, local commits) and Gemini 4 Argon (writer) through Orca, review the diff with git, validate the docs, and push/merge only with the owner's OK. Use for /orchestrate, "project X has a bug / needs a feature / needs optimization", "map project X", or "status of my projects".
---

# Orchestrate

Workflow repo: `$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow` (`WF`).
Follow `WF/taskflow.md`; this is the entry point. Your role: `WF/roles/claude-lead.md`.

## Start

```
WF/scripts/wf.sh list
WF/scripts/wf.sh writer-check        # writer=gemini, or writer=claude (you write the docs)
WF/scripts/resource-gate.sh status
```

Unknown project → ask path and type, `WF/scripts/wf.sh new <name> <path> <type>`.
First Orca use this session → `orca skills get orchestration` once, keep its safety floor.

## Per request

1. One line per project: job + size (S/M/L). One question to the owner: priority order.
2. `wf.sh map-status <name>`: missing → one-time map into `WF/projects/<name>/codemap.md`
   (template there) + `map-stamp`; stale → read only the listed changed files that matter, update
   the map, `map-stamp`; behind origin → tell the owner.
3. From the codemap, open only the exact files to change. Write `WF/projects/<name>/task.md`
   (20–40 lines, exact `## May edit`, file:symbol pointers in Notes).
4. `orca worktree create` from `base:` → `wf.sh prep <name> <worktree>` →
   `resource-gate.sh wait agent` → Codex (local commits only) → `check --wait`.
5. `wf.sh check <name> <worktree>` → PASS or rework (`## Rework`, `--retry-of`).
6. Writer: Gemini (`--agent antigravity`) documents from git → `wf.sh collect`. If writer=claude
   or Gemini fails on model/quota/context → write summary + suggestions yourself.
7. `wf.sh diff <name> <worktree>`: review the code against the task (role checklist), check the
   docs match the diff → verdict: revise, or report to the owner → "OK to push?"
8. On OK: `wf.sh ship`, `orca worktree rm`, `wf.sh merge`; update the touched codemap sections +
   `map-stamp`. Drop: `wf.sh archive <name> dropped`.

## Token rules

Never re-read a whole codebase: codemap first, then only exact files and the task's diff.
`wf.sh diff` over raw `git diff`. Short tasks with pointers. State lives in files.

## Hard rules

No push/merge/pull/deletion without the owner's OK. Workers only in task worktrees, local commits
only. Every worker start passes `resource-gate.sh wait agent`; every heavy command passes
`resource-gate.sh run heavy --`.
