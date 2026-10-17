# workflow

A multi-agent workflow for working on several projects at once. You talk to one lead agent
(Claude) in this folder. Gemini reads the code and writes docs and summaries, Codex builds,
debugs, tests and does QA, and small scripts do the bookkeeping, so Claude only spends tokens
on decisions. Workers run in [Orca](https://github.com/stablyai/orca) worktrees; a memory gate
keeps the laptop from choking. Nothing is pushed without your OK.

```
you ─▶ Claude (lead, decides) ─▶ Gemini: scout ─▶ Codex: build/debug/test/QA ─▶ wf.sh check
          ▲                                                                       │
          └── "needs change? OK to push?" ◀── Gemini: docs, summary, suggestions ◀┘
```

| I want to... | Read |
|---|---|
| Use it | [Skill-usage.md](Skill-usage.md) |
| Add a project | [docs/project-setup.md](docs/project-setup.md) |
| Know exactly what happens to a task | [taskflow.md](taskflow.md) |
| Know what each AI does | [roles/](roles/) |
| Keep memory under control | [docs/resources.md](docs/resources.md) |
| Look up an Orca command | [docs/orca.md](docs/orca.md) |
| Change the workflow itself | [AGENTS.md](AGENTS.md) |

## Install

Needs: Orca desktop app, Claude Code, Codex CLI, Antigravity CLI (`agy`), `git`, `git-lfs`, `gh`,
all logged in; Unity CLI (`unity`) for Unity projects.

```
git clone https://github.com/EisenDev/workflow ~/workspace/Agent-Workflow
~/workspace/Agent-Workflow/scripts/install.sh
```

Per-project folders (`projects/<name>/`) are git-ignored: task history and local paths stay on
your machine.
