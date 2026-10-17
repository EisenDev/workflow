<!-- Paste this section into the project's own AGENTS.md (create it if missing). Codex and
     Antigravity read AGENTS.md automatically; Claude reads it via CLAUDE.md. -->

## Agent workflow

This project uses the Agent-Workflow (`EisenDev/workflow`, local `~/workspace/Agent-Workflow`).

- Claude is the lead; Codex builds; Gemini (Antigravity) writes docs. Roles: `roles/` in the
  workflow repo.
- Project settings, test command and forbidden paths: `.agents/project.md`.
- Task briefs: `.agents/tasks/T-NNN.md`. Reports: `.agents/reports/T-NNN.md`.
- If you were started by Orca with a task, your brief and the Orca preamble are your instructions:
  stay inside the brief's Ownership, run its Acceptance, finish with one `worker_done`.
- Workers never edit the main folder, never push, never merge.
