# workflow

A reusable multi-agent workflow for game, web and software projects. You talk to one lead agent
(Claude). Claude plans the work, hands coding to Codex and writing to Gemini (Antigravity) through
[Orca](https://github.com/stablyai/orca), reviews and tests everything, and reports back. Nothing
gets merged without your OK.

```
you ──▶ Claude (lead) ──▶ Orca ──▶ Codex (builder)   ─┐  each in its own git worktree
          ▲   │                └─▶ Gemini (writer)   ─┤
          │   └──── review + tests ◀─── worker_done ◀─┘
          └── plain-language report, "OK to merge?"
```

## Start here

| I want to... | Read |
|---|---|
| Install this on my machine | [Install](#install) below |
| Use it day to day | [docs/usage.md](docs/usage.md) |
| Add a project | [docs/project-setup.md](docs/project-setup.md) |
| Know exactly what happens to a task | [taskflow.md](taskflow.md) |
| Know what each AI does | [roles/](roles/) |
| Look up an Orca command | [docs/orca.md](docs/orca.md) |
| Keep memory under control / use GitHub Actions | [docs/resources.md](docs/resources.md) |
| Change the workflow itself | [AGENTS.md](AGENTS.md) |

## Install

Needs: Orca desktop app (running), Claude Code, Codex CLI, Antigravity CLI (`agy`), `git`,
`git-lfs`, `gh`, all logged in. For Unity projects also the Unity CLI (`unity`).

```
git clone https://github.com/EisenDev/workflow ~/workspace/Agent-Workflow
~/workspace/Agent-Workflow/scripts/install.sh
```

`install.sh` links the three skills: `orchestrate` (Claude), `workflow-builder` (Codex),
`workflow-writer` (Antigravity). Cloned somewhere else? Set `AGENT_WORKFLOW_HOME` to that path.

## Layout

```
AGENTS.md CLAUDE.md GEMINI.md   instructions per agent (AGENTS.md is shared)
taskflow.md                     the task lifecycle, step by step
roles/                          job description per agent
profiles/                       rules per project type (unity; web, software planned)
templates/                      task brief, report, project.md, AGENTS.md snippet
skills/                         the three skills
scripts/install.sh
docs/                           usage, project setup, Orca cheat sheet
```
