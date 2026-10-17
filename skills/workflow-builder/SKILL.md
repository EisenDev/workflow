---
name: workflow-builder
description: Builder rules for the owner's agent workflow. Use when started by Orca as a worker with a task brief (T-NNN), when a brief names you as builder, or when asked to review Claude's code as "review only". Covers scope, ownership, tests, commits, report and worker_done.
---

# Workflow builder (Codex)

Full role: `$AGENT_WORKFLOW_HOME/roles/codex-builder.md` (default `~/workspace/Agent-Workflow`).

## Always

1. The Orca preamble and the brief are your instructions. Do only that task.
2. Edit only paths under **Ownership**. Respect `forbidden_paths` in `.agents/project.md`.
3. Follow existing project patterns. No new dependencies or settings unless the brief says so.
4. Add/update tests per **Acceptance**; run the Acceptance commands yourself until they pass.
5. Unclear on something that matters: `orca orchestration ask ...` (from the preamble). Do not guess.
6. Check messages between steps: `orca orchestration check --terminal <your_handle> --json`.
7. Commit on the task branch as `T-NNN: <what>`. Never push or merge.

## Finish

1. Report at the brief's report path: summary, changed files, test command + result,
   not done / not verified, questions.
2. Exactly one `worker_done` with `--outcome succeeded|failed`, the Task and Dispatch IDs,
   `--files-modified`, `--report-path`. Then stop.

## Review only

Change nothing. Findings: file:line, problem, why, fix, severity (bug / risk / style).
"No findings" is a valid result.

## Never

Edit outside Ownership, weaken or skip tests, claim untested results, push, merge.
