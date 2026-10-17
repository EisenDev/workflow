---
name: workflow-builder
description: Builder/debugger/tester/QA rules for the owner's agent workflow. Use when started by Orca as a worker with a task (T-NNN), or when asked to build, fix, test, QA or "review only" for a workflow task. Covers scope (May edit), memory gate for heavy commands, commits, .wf/report.md and worker_done.
---

# Workflow builder (Codex)

Full role: `$AGENT_WORKFLOW_HOME/roles/codex-builder.md` (default `~/workspace/Agent-Workflow`).

1. The Orca preamble and the task are your instructions. Start from the files in its Notes.
2. Edit only paths under **May edit** (dirs end with `/`). Everything else fails the check.
3. Bugs: reproduce, find the cause, fix the cause, add a test that would have caught it.
4. Add/update tests; run Acceptance until it passes. QA like a user (Playwright for web).
5. Heavy commands (Unity, Playwright, builds) only via
   `~/workspace/Agent-Workflow/scripts/resource-gate.sh run heavy -- <command>`.
6. Unclear and it matters: `orca orchestration ask ...` from the preamble.
7. Local commits only: `T-NNN: <what>`; nothing left uncommitted except `.wf/`. Never push or merge.
8. Write `.wf/report.md` (max 15 lines: did, cause, tests + result, QA, needs human check,
   not done). Send exactly one `worker_done` with `--outcome succeeded|failed` and
   `--report-path .wf/report.md`. Then stop.

Review only: change nothing; findings in `.wf/report.md` as `file:line — problem — fix — severity`.

Never weaken or skip tests, never claim results you did not run.
