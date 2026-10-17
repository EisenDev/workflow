---
name: orchestrate
description: Run the owner's multi-project agent workflow as lead from the workflow repo - take requests for one or more projects (solbeast, owsi, ...), ask priority, start Gemini (scout/docs) and Codex (build/debug/test/QA) through Orca, check results with scripts, report what needs changing, and push/merge only with the owner's OK. Use for /orchestrate, "project X has a bug / needs a feature / needs optimization", "give this to Codex/Gemini", or "status of my projects".
---

# Orchestrate

Workflow repo: `$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow` (`WF`).
Follow `WF/taskflow.md`; this is the entry point. Your role: `WF/roles/claude-lead.md`.

## Start

```
WF/scripts/wf.sh list
WF/scripts/resource-gate.sh status
```

Unknown project name → ask for its path and type, then `WF/scripts/wf.sh new <name> <path> <type>`.
First Orca use this session → `orca skills get orchestration` once, keep its safety floor.

## Per request

1. One line per project: job + size (S/M/L). One question to the owner: priority order (suggest one).
2. M/L: worktree + Gemini scout → `.wf/context.md`. `wf.sh prep <worktree>`.
3. Write `WF/projects/<name>/task.md` (template layout, 20–40 lines, exact `## May edit`).
4. `resource-gate.sh wait agent` → Codex builds/debugs/tests/QA → `check --wait`.
5. `wf.sh check <name> <worktree>` → PASS or rework (`## Rework`, `--retry-of`).
6. Gemini docs + summary + suggestions → `wf.sh collect <name> <worktree>`.
7. Read `summary.md` + `suggestions.md` + check line → report per project (format in the role
   file) → "OK to push?"
8. On OK: `wf.sh ship`, `orca worktree rm`, `wf.sh merge`. Drop: `wf.sh archive <name> dropped`.

## Token rules

Never read the codebase or full diffs. Read only script output, the task, context, summary and
suggestions; open code only at a file:line they point to. Keep tasks short. State lives in files.

## Hard rules

No push/merge/deletion without the owner's OK. Workers only in task worktrees. Every worker start
passes `resource-gate.sh wait agent`; every heavy command passes `resource-gate.sh run heavy --`.
