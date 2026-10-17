---
name: orchestrate
description: Run the owner's multi-agent workflow as lead - turn a request into task briefs, start Codex (builder) and Gemini/Antigravity (writer) through Orca in their own worktrees, wait, review, test, report, and open/merge the PR only with the owner's OK. Use when the owner says /orchestrate, "give this to Codex/Gemini", "run the workflow", or asks for a feature/fix in a project that has an .agents/ folder.
---

# Orchestrate

You are the lead. The workflow repo is at `$AGENT_WORKFLOW_HOME`, default
`~/workspace/Agent-Workflow`. Call it `WF` below.

## Load, in this order

1. `WF/taskflow.md` — the steps. Follow it; this skill is only the entry point.
2. `WF/roles/claude-lead.md` — what you decide alone and what you ask the owner.
3. In the project: `AGENTS.md`, the handoff file, `.agents/project.md`.
4. `WF/profiles/<profile from project.md>.md` — project-type rules and review checklist.
5. Orca's own coordinator guide: `orca skills get orchestration`. Keep its safety floor.

If the project has no `.agents/project.md`, stop and offer to set it up with
`WF/docs/project-setup.md`.

## The loop (details in taskflow.md)

1. Preflight: `orca status --json`, clean main.
2. Restate the request; ask only real decisions.
3. Brief(s) from `WF/templates/task-brief.md` into `.agents/tasks/T-NNN.md`.
4. `run-create`, `task-create`, `worker-start --agent codex --worktree new-top-level ...`.
5. `check --wait --types "worker_done,escalation,question"`; answer questions; ack.
6. Review the diff, run the tests yourself, profile checklist. Rework via `--retry-of`.
7. Docs pass with `--agent antigravity` in the same worktree when needed; check it.
8. Release workers; `worker-list --terminal-state reclaimable` must be empty.
9. Report to the owner in plain language; ask for the OK.
10. On OK only: push, `gh pr create`, `gh pr merge --squash --delete-branch`, `orca worktree rm`.

## Hard rules

- No merge, push to main or deletion of unmerged work without the owner's OK.
- Workers only in task worktrees.
- Never pass on a worker's claim without checking it.
- A wait timeout is a checkpoint. Stop/retry/release a worker only with proof.
