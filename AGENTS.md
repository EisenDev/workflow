# AGENTS.md

Shared rules for every agent (Claude, Codex, Gemini/Antigravity). Read this first. Tool-specific
additions: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md). Codex reads only this file.

## What this repo is

A reusable, project-independent multi-agent workflow for game, web and software development.
The owner talks to one lead agent (Claude). Claude plans, writes task briefs, hands them to Codex
and Gemini through Orca, reviews every result, runs the tests, reports back in plain language,
and opens/merges the PR with the owner's OK.

This repo holds the roles, taskflow, templates, profiles, skills and docs. A project that uses the
workflow only keeps a small `.agents/` folder. Nothing in here is about any one project.

GitHub: `EisenDev/workflow`. Local: `~/workspace/Agent-Workflow` (`$AGENT_WORKFLOW_HOME`).

## The three agents

| Agent | Runs as | Role | Full description |
|---|---|---|---|
| Claude | Claude Code, Orca coordinator | Lead: owner contact, plans, briefs, review, tests, PR, merge | [roles/claude-lead.md](roles/claude-lead.md) |
| Codex | `orca ... --agent codex` | Builder: code + tests from a brief; second-opinion reviewer | [roles/codex-builder.md](roles/codex-builder.md) |
| Gemini | `orca ... --agent antigravity` (`agy`, Gemini 4 Argon) | Writer: docs, handoff, changelog, story text, long reads | [roles/gemini-writer.md](roles/gemini-writer.md) |

Orca (stablyai/orca, `orca` CLI, desktop app must be running) is the runtime: worktrees, starting
workers, waiting, messages, liveness. How one task flows: [taskflow.md](taskflow.md).

## Repo map

```
AGENTS.md CLAUDE.md GEMINI.md README.md   entry points
taskflow.md                               the one source for the task lifecycle
roles/       one file per agent: job, inputs, outputs, limits
profiles/    rules per project type: unity.md (web.md, software.md planned)
templates/   task-brief.md report.md project.md project-agents-snippet.md github/unity-tests.yml
skills/      orchestrate (Claude), workflow-builder (Codex), workflow-writer (Gemini)
scripts/     install.sh (links skills), resource-gate.sh + resource-watch.sh (memory)
docs/        usage.md  project-setup.md  orca.md  resources.md
```

## Rules for every agent

1. **Scope.** Do the task you were given, nothing more. No drive-by refactors or reformatting.
2. **Ownership.** Edit only the files your brief allows. Need another file? Ask, do not just edit.
3. **No invented facts.** Unknown command flags, versions, behaviour: check (`--help`, the code)
   or write `TODO(owner)` / "verify". Never present a guess as fact.
4. **Worktrees only.** Workers never run in the owner's main folder.
5. **Owner decides.** Product, design, story and merge decisions belong to the owner. Ask through
   the lead; workers use `orca orchestration ask`.
6. **Plain language.** Short sentences, concrete names, no filler. The owner is not always in the
   context.
7. **Truthful reports.** Failed tests, skipped steps and uncertainty are reported as such.
8. **Secrets.** Never commit credentials, tokens or `.env` files; never print them in reports.

## Rules for editing this repo

- Keep it project-independent. Project details belong in that project's `.agents/`.
- One source per topic: the flow lives in `taskflow.md`, role details in `roles/`, project-type
  rules in `profiles/`. Other files link instead of copying.
- Commands in docs must be verified on the owner's machine; otherwise mark them "verify".
- Skills in `skills/` are linked, not copied, by `scripts/install.sh`; edits take effect directly.
  Rerun the script only after adding a new skill.
- Date status lines (`Status (YYYY-MM-DD): ...`).

## Verified tools (owner's laptop, 2026-10-17)

- Orca: `orca orchestration ...` (run-create, task-create, worker-start, check, reply, ask,
  worker-list/read/release, gate-*), `orca worktree ...`. Repo hooks in `orca.yaml`
  (`scripts.setup`, `scripts.archive`). Cheat sheet: [docs/orca.md](docs/orca.md).
- Codex CLI 0.163: `codex exec -C <dir> -s <sandbox> -m <model> -o <file> "<prompt>"`.
- Antigravity CLI `agy` 1.4.0: `agy -p "<prompt>" --model gemini-4-argon-medium
  --mode accept-edits --output-format json`; reads `AGENTS.md` and `GEMINI.md`.
- Unity CLI 1.0.0-beta.12: `unity test <project> --mode EditMode --output <xml>`
  (exit 0 pass, 8 tests failed, 6 never ran).
- `git`, `git-lfs`, `gh`.

## Status and build order

Status (2026-10-17): docs written, nothing run end-to-end yet.

1. [x] Repo on GitHub (`EisenDev/workflow`).
2. [x] Taskflow, roles, templates, Unity profile, docs.
3. [x] Skills written and installed with `scripts/install.sh`.
4. [x] Memory gate + watcher (`docs/resources.md`), tested 2026-10-17; GitHub Actions template
   for Unity tests (not yet run).
5. [ ] End-to-end test on a throwaway Unity repo; settle the "verify" items in `taskflow.md`.
6. [ ] Web and software profiles.

Limits: start with one Codex lane and one Gemini lane; merge only with the owner's OK until the
system has proven itself; each tool has its own login and quota and can run out mid-task.
