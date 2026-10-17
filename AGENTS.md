# AGENTS.md

Shared rules for every agent (Claude, Codex, Gemini/Antigravity). Read this first. Tool-specific
additions: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md). Codex reads only this file.

## What this repo is

A reusable multi-agent workflow for several game, web and software projects at once. The owner
talks to one lead agent (Claude) in this folder. Claude knows each codebase through a one-time
codemap, reads only the files and diffs that matter, and gives the verdict; Codex builds, debugs,
tests and does QA with local commits; Gemini 4 Argon writes the docs from git; scripts do the
bookkeeping. Goal: best quality without wasting tokens or running the laptop out of memory.

GitHub: `EisenDev/workflow` (public). Local: `~/workspace/Agent-Workflow` (`$AGENT_WORKFLOW_HOME`).

## The three agents

| Agent | Runs as | Role | Full description |
|---|---|---|---|
| Claude | Claude Code, Opus 5.5 medium, Orca coordinator | Lead: codemap, tasks, diff review, verdict, owner report, push/merge on OK; writer fallback | [roles/claude-lead.md](roles/claude-lead.md) |
| Codex | `orca ... --agent codex` | Builder, debugger, tester, QA | [roles/codex-builder.md](roles/codex-builder.md) |
| Gemini | `orca ... --agent antigravity` (`agy`, Gemini 4 Argon High) | Writer: docs, summary, suggestions, long text | [roles/gemini-writer.md](roles/gemini-writer.md) |

Orca (stablyai/orca, `orca` CLI; the desktop app must be running) runs the workers in git
worktrees. The task lifecycle: [taskflow.md](taskflow.md). How the owner uses it:
[docs/usage.md](docs/usage.md).

## Repo map

```
AGENTS.md CLAUDE.md GEMINI.md README.md   entry points
taskflow.md                               the one source for the task lifecycle
roles/       job, inputs, outputs, limits per agent
profiles/    rules per project type: unity.md, web.md (software.md planned)
projects/    _template/ (published) + one folder per project (git-ignored, local only)
skills/      orchestrate (Claude), workflow-builder (Codex), workflow-writer (Gemini)
scripts/     wf.sh (projects, codemap status, check, diff, archive, ship), resource-gate.sh +
             resource-watch.sh (memory),
             install.sh (links skills)
docs/        usage.md  project-setup.md  resources.md  orca.md
.claude/settings.json                     Claude model + effort for this folder
```

## Rules for every agent

1. **Scope.** Do the task you were given, nothing more. No drive-by refactors or reformatting.
2. **May edit.** Change only the paths the task allows. Need another file? Ask.
3. **No invented facts.** Unknown flags, versions, behaviour: check, or write `TODO(owner)` /
   "verify". Never present a guess as fact.
4. **Worktrees only.** Workers never run in the owner's main folder.
5. **Owner decides** product, design, story, priority and every push/merge.
6. **Memory.** Heavy commands (Unity, Playwright, builds) only through
   `scripts/resource-gate.sh run heavy -- <cmd>`.
7. **Short outputs.** Reports, summaries and context files have line limits; keep to them.
8. **Truthful.** Failed tests, skipped steps and uncertainty are reported as such.
9. **Secrets.** Never commit credentials, tokens or `.env` files; never print them.
10. **Public repo.** Nothing project-specific goes into tracked files here; it belongs in
    `projects/<name>/` (git-ignored).

## Rules for editing this repo

- One source per topic: flow in `taskflow.md`, role details in `roles/`, project-type rules in
  `profiles/`, owner how-to in `docs/usage.md`. Others link instead of copying.
- Commands in docs must be verified on the owner's machine; otherwise mark them "verify".
- Skills are linked by `scripts/install.sh`; edits take effect directly.
- Date status lines (`Status (YYYY-MM-DD): ...`).

## Verified tools (owner's laptop, 2026-10-17)

- Orca: `orca orchestration ...`, `orca worktree ...`, `orca terminal ...` ([docs/orca.md](docs/orca.md)).
- Codex CLI 0.163; Antigravity CLI `agy` 1.4.0 (reads `AGENTS.md` and `GEMINI.md`).
- Unity CLI 1.0.0-beta.12: `unity test <project> --mode EditMode --output <xml>` (0 pass, 8 failed, 6 no verdict).
- `git`, `git-lfs`, `gh`, systemd user scopes (memory caps and freezing).

## Status and build order

Status (2026-10-18): five projects registered (local `projects/`); owsi passed a full dry-run
check; owsi-giveaway and berry have codemaps (with docs map). Ready for the first real task.

1. [x] Repo on GitHub, roles, taskflow, Unity + web profiles, skills (installed), docs.
2. [x] Memory gate + watcher, `wf.sh` (new, list, prep, map-status/stamp, diff, writer-check,
   check, collect, archive) tested on real repos.
3. [x] Codemap flow; Gemini updates project `docs/` from the codemap's docs map.
4. [ ] First real task end to end; settle the "verify" list in `taskflow.md`; test
   `wf.sh ship`/`merge` on a real PR.
5. [ ] Software profile.
