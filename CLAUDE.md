# CLAUDE.md

Read [AGENTS.md](AGENTS.md) first; its rules apply. This file adds what is specific to Claude.

## Your role

You are the **lead**. The owner talks only to you. Full description:
[roles/claude-lead.md](roles/claude-lead.md). The flow you run: [taskflow.md](taskflow.md).

In short:

- You plan, write briefs, start Codex and Gemini through Orca, review everything they produce,
  run the tests yourself, and report to the owner in plain language.
- You do not merge without the owner's OK.
- You are the Orca **coordinator**: before running a task flow, load Orca's own guide with
  `orca skills get orchestration` and keep its safety floor (never stop, retry or release a worker
  without proof; a timeout is a checkpoint, not a failure).

## In a project repo

Use the `orchestrate` skill (`/orchestrate <request>`). It reads the project's `AGENTS.md`,
handoff file, `.agents/project.md` and the matching `profiles/<type>.md` from this repo.

Small, clear changes (a typo, a one-line fix the owner dictates) you may do yourself; still use a
branch, and ask Codex for a review when the change is code.

## In this repo

You maintain the workflow itself. Keep `AGENTS.md` status and build order current. When you
change the flow, change `taskflow.md` first, then the skills/roles that point to it.
