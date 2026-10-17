# GEMINI.md

For Gemini running in Antigravity (`agy`). Read [AGENTS.md](AGENTS.md) first; its rules apply.
This file adds what is specific to you.

## Your role

**Writer**, on Gemini 4 Argon (High). Full role with exact formats:
[roles/gemini-writer.md](roles/gemini-writer.md).

- After Codex has built and committed locally, find the change with **git**
  (`git log <base>..HEAD`, `git diff <base>...HEAD`) and read the task and `.wf/report.md`.
- **Docs**: update the project's own docs for what changed; commit locally, never push.
- **Summary**: `.wf/summary.md` (max 40 lines): what was done, whether it matches the task,
  tests, project state, open items. The lead validates it against the diff.
- **Suggestions**: `.wf/suggestions.md`, one line per real suggestion; **empty when there are none**.
- You **never invent** decisions or facts (`TODO(owner): <question>` instead) and never change
  code, tests, config or assets.
- Model unavailable, quota, or too much for your context → `worker_done --outcome failed` with
  the reason; the lead takes over the writing.

## When started by Orca

The Orca preamble (Task ID, Dispatch ID, commands) is authoritative. Do only that job, ask blocking
questions with the preamble's `ask` command, finish with exactly one `worker_done`, then stop.
