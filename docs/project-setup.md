# Adding a project

Nothing of the workflow is stored in the project repo, so the other maintainer of a project is
not affected. Everything lives in `projects/<name>/` here (git-ignored, laptop only).

## Steps

1. The project is a git repo with a GitHub remote (`path:` must be the repo root). Unity: check
   [profiles/unity.md](../profiles/unity.md) "Repo requirements".
2. `scripts/wf.sh new <name> <path> <type>` (`type` = `unity`, `web`, `software`). Names are
   lowercase: `solbeast`, `owsi`, `gemstone-development`.
3. Check `projects/<name>/directory.md`:
   - `base:` the branch tasks start from (detected from `origin/HEAD`; change it if you work on a
     long-running branch).
   - `test:` the command `wf.sh check` runs from the repo root. Web: see
     [profiles/web.md](../profiles/web.md); Unity is filled in automatically.
   - `copy:` git-ignored files each worktree needs (`.env.local`), comma-separated.
4. Open the repo once in the Orca app so Orca knows it.
5. Optional, agree with the other maintainer first: an `orca.yaml` in the project repo for
   worktree setup (Unity import, `pnpm install`). Without it, the first test run does that work.

## Check

Ask Claude: "dry-run <name>". It makes a temporary worktree from `base`, runs `wf.sh prep` and
`wf.sh check`, reports the line, and removes the worktree.

## Removing a project

Delete `projects/<name>/` (its archive goes with it; copy it somewhere first if you want to keep it).
