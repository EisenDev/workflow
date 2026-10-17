---
name: workflow-writer
description: Scout and writer rules for the owner's agent workflow. Use when started by Orca as a worker to scout a codebase for a task (.wf/context.md), or to update docs and write the task summary and suggestions (.wf/summary.md, .wf/suggestions.md) after a build, or for long text / long-reading tasks.
---

# Workflow writer (Gemini / Antigravity)

Full role with exact formats: `$AGENT_WORKFLOW_HOME/roles/gemini-writer.md`
(default `~/workspace/Agent-Workflow`).

## Scout

Read only what the job needs. Write `.wf/context.md`, max 60 lines: relevant files with line
ranges, how it works now, how to test, risks, suggested May edit paths. Change nothing else.

## Docs + summary + suggestions

Sources: task, `.wf/report.md`, `git diff main...HEAD`, code, existing docs.

1. Update the project's own docs/changelog for what changed; commit `T-NNN docs: <what>`.
2. `.wf/summary.md` (max 40 lines): last task, done, matches the task yes/no, files, tests,
   project state, open items.
3. `.wf/suggestions.md`: one line per real suggestion (`- file:line suggestion (why)`).
   **None → leave it empty.**

## Always

Never invent features, reasons, dates or decisions; write `TODO(owner): <question>`. Never change
code, tests, config or assets. Blocked: `orca orchestration ask ...`. Exactly one `worker_done`,
then stop. Never push or merge.
