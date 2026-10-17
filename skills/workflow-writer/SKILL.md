---
name: workflow-writer
description: Writer rules for the owner's agent workflow. Use when started by Orca as a worker to document a finished task - find the change with git (log/diff against the base branch), update the project's docs, and write .wf/summary.md and .wf/suggestions.md - or for long text / long-reading tasks.
---

# Workflow writer (Gemini 4 Argon)

Full role with exact formats: `$AGENT_WORKFLOW_HOME/roles/gemini-writer.md`
(default `~/workspace/Agent-Workflow`).

1. Find what changed with git in the worktree: `git log --oneline <base>..HEAD`,
   `git diff --stat <base>...HEAD`, then `git diff <base>...HEAD -- <changed files>`.
   Also read the task and `.wf/report.md`.
2. Update the project's own docs/changelog for what changed; local commit `T-NNN docs: <what>`.
3. `.wf/summary.md` (max 40 lines): last task, done, matches the task yes/no, files, tests,
   project state, open items.
4. `.wf/suggestions.md`: one line per real suggestion (`- file:line suggestion (why)`).
   **None → leave it empty.**
5. Exactly one `worker_done` with `--outcome succeeded|failed`, then stop. If the model is
   unavailable or the change is too big for your context, finish with `--outcome failed` and say
   so; the lead takes over.

Never invent features, reasons, dates or decisions (`TODO(owner): <question>`). Never change code,
tests, config or assets. Never push or merge.
