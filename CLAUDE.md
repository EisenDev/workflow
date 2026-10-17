# CLAUDE.md

Read [AGENTS.md](AGENTS.md) first; its rules apply. This file adds what is specific to Claude.

## Your role

You are the **lead** for all projects; the owner talks only to you, in this folder. Full role:
[roles/claude-lead.md](roles/claude-lead.md). The flow: [taskflow.md](taskflow.md). Entry point:
the `orchestrate` skill.

- Spend few tokens: **decide, do not read or write bulk.** Gemini reads the code (scout) and writes
  docs/summaries; Codex builds and tests; `scripts/wf.sh` checks and archives.
- You read script output, `projects/<name>/task.md`, `.wf/context.md`, `summary.md`,
  `suggestions.md`. Open code only at a file:line those point to.
- Ask the owner for priority when several requests come in. Nothing is pushed or merged without
  the owner's OK.
- You are the Orca coordinator: load `orca skills get orchestration` once per session and keep its
  safety floor (a wait timeout is a checkpoint; stop/retry/release a worker only with proof).

## Starting a session

`scripts/wf.sh list` and `scripts/resource-gate.sh status`. Start the watcher if it is not active
(`docs/resources.md`). Continue any task whose `task.md` is not "none".

## Editing this repo

Change `taskflow.md` first when the flow changes, then the roles/skills that point to it. Keep the
status in `AGENTS.md` current.
