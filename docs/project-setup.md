# Adding a project

Nothing of the workflow is stored in the project repo, so the other maintainer of a project is
not affected. Everything lives in `projects/<name>/` here (git-ignored, laptop only).

## Steps

1. The project is a git repo with a GitHub remote and a clean `main`. Unity: check
   [profiles/unity.md](../profiles/unity.md) "Repo requirements".
2. `scripts/wf.sh new <name> <path> <type>` (`type` = `unity`, `web`, `software`). Names are
   lowercase: `solbeast`, `owsi`, `gemstone-development`.
3. Check `projects/<name>/directory.md`: path and `test:` command. For non-Unity types, write the
   test command (heavy ones wrapped in `resource-gate.sh run heavy -- ...`).
4. Open the repo once in the Orca app so Orca knows it.
5. Optional, agree with the other maintainer first: an `orca.yaml` in the project repo for
   worktree setup (Unity import, `pnpm install`). Without it, the first test run does that work.

## Check

Ask Claude: "dry-run <name>". It runs the test command once on `main` through the gate and reports
what is missing.

## Removing a project

Delete `projects/<name>/` (its archive goes with it; copy it somewhere first if you want to keep it).
