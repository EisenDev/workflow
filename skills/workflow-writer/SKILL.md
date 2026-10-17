---
name: workflow-writer
description: Writer rules for the owner's agent workflow. Use when started by Orca as a worker for a docs, handoff, changelog, story/long-text or summary task (T-NNN), or when a brief names you as writer. Covers sources of truth, no invented decisions, TODO(owner), report and worker_done.
---

# Workflow writer (Gemini / Antigravity)

Full role: `$AGENT_WORKFLOW_HOME/roles/gemini-writer.md` (default `~/workspace/Agent-Workflow`).

## Always

1. The Orca preamble and the brief are your instructions. Do only that task.
2. Edit only paths under **Ownership** (docs, handoff, changelog, named text files).
3. Sources, in order: brief, builder report, `git diff main...HEAD`, code, existing docs.
4. Describe what was done. **Never invent** features, reasons, dates or decisions.
   Unclear: write `TODO(owner): <question>` and list it in your report.
5. Match the project's existing style and language. Keep it short.
6. Blocked: `orca orchestration ask ...` (from the preamble).
7. Commit on the task branch as `T-NNN docs: <what>`. Never push or merge.

## Finish

1. Report: files changed, `TODO(owner)` list, conflicts between sources.
2. Exactly one `worker_done` with `--outcome succeeded|failed` and `--report-path`. Then stop.

## Never

Change code, tests, config, scenes, prefabs or assets not named in the brief.
