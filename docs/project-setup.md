# Adding a project to the workflow

Once per project. Claude can do these steps for you ("set this project up for the workflow");
it will ask before changing project settings.

## 1. Git and GitHub

- The project must be a git repo with a GitHub remote and a clean `main`.
- Profile-specific requirements first: Unity → [profiles/unity.md](../profiles/unity.md)
  "Repo requirements" (Git LFS, Unity .gitignore, Force Text, Visible Meta Files).

## 2. The `.agents/` folder

```
<project>/.agents/
  project.md      from templates/project.md, filled in
  tasks/          briefs (T-001.md, ...)
  reports/        worker reports
```

Commit `.agents/` to the project. Briefs and reports are the project's history of who did what.

## 3. The project's AGENTS.md

Paste [templates/project-agents-snippet.md](../templates/project-agents-snippet.md) into the
project's `AGENTS.md` (create it if missing). If the project has a `CLAUDE.md`, make sure it says
to read `AGENTS.md`. Optional `GEMINI.md`: one line pointing to `AGENTS.md`.

## 4. Orca

- Add the repo in the Orca app (or `orca worktree list` shows it after first use).
- Add `orca.yaml` at the repo root if new worktrees need setup (Unity: Library import; web:
  `pnpm install`). Example in the profile.

## 5. Check

Ask Claude: "dry-run the workflow here". Claude runs preflight from `taskflow.md` step 0 and the
profile, runs the test command once on `main`, and reports what is missing.
