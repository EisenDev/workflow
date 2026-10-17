# T-NNN: <short title>

Status: draft            <!-- draft | dispatched | built | reviewed | documented | reported | merged | blocked | abandoned -->
Worker: codex            <!-- codex | antigravity | codex (review only) -->
Branch: tNNN-<slug>
Report: .agents/reports/T-NNN.md
Orca: run=<run_id> task=<task_id> dispatch=<dispatch_id> worktree=<path>

## Goal

<One or two sentences: what the owner wants and why.>

## Target

<Files, component or system in scope. Point to the entry files.>

## Change

<The concrete result. Behaviour before -> after. Be specific.>

## Constraints

- Follow the project's `AGENTS.md` and `.agents/project.md` (forbidden paths apply).
- Profile rules: `profiles/<type>.md`.
- <Invariants, compatibility, patterns to follow, things not to do.>

## Ownership

May edit:
- <path>
- <path>

<Unity: scenes/prefabs this task owns, by name. "none" if none.>

## Acceptance

Must pass (run them yourself):
```
<test command from .agents/project.md, with filters if useful>
```
Also:
- <observable evidence: output, grep, file exists>

Owner checks (worker cannot): <visuals, feel, audio — or "none">

## Context

<Relevant files, earlier decisions, links. Point, do not paste.>

## When done

1. Commit on the branch: `T-NNN: <what>`. Do not push.
2. Write the report at the path above (format: `templates/report.md` in the workflow repo).
3. Send exactly one `worker_done` with `--outcome succeeded|failed`, `--files-modified`,
   `--report-path`. Then stop.

<!-- Claude appends "## Rework N" sections below with review notes. -->
