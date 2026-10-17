# Using the workflow day to day

## Start a session

1. Open the Orca desktop app.
2. In Orca, open the project and start a Claude Code terminal in the project's main folder.
   (Claude must run inside Orca to be the coordinator.)
3. Ask for what you want:

   ```
   /orchestrate Add a double-jump to the player controller, with tests
   ```

   Without the slash command, "give this to Codex" or any feature/fix request in a project with an
   `.agents/` folder also triggers the skill.

## What happens next

| You see | Meaning | You do |
|---|---|---|
| Claude restates the request, maybe asks a question | Planning | Answer decisions only you can make |
| A new worktree + Codex terminal appears in Orca | Builder started | Nothing; watch if you like |
| Claude asks you something mid-task | A worker hit a real decision | Answer; Claude passes it on |
| A Gemini terminal appears | Docs pass | Nothing |
| Claude's report: changes, tests, "please check in the Editor", "OK to merge?" | Done, reviewed, tested | Check what Claude couldn't (visuals, feel), then OK or ask for changes |
| "Blocked: Codex out of quota" (or similar) | A tool stopped | Top up / log in, then tell Claude to continue |

Watching from your phone: the Orca mobile app shows the same terminals and notifies when a worker
finishes.

## Answering "OK to merge?"

- **OK** → Claude pushes the branch, opens the PR, squash-merges, removes the worktree.
- **Change X** → Claude writes a rework note and sends it back to Codex.
- **Not now** → branch and worktree stay; the task is listed as "waiting for OK".
- **Drop it** → Claude asks before deleting the branch and worktree.

## Several requests at once

Start with one Codex lane: Claude runs one build task at a time and queues the rest as briefs in
`.agents/tasks/`. More lanes come after the first end-to-end test.

## Where things are written

| What | Where |
|---|---|
| Task briefs (status in the header) | `<project>/.agents/tasks/T-NNN.md` |
| Worker reports | `<project>/.agents/reports/T-NNN.md` (on the task branch) |
| Worktrees | listed by `orca worktree list`, visible in the Orca sidebar |
| Progress across worktrees | `orca worktree ps` |

## When something goes wrong

- **Worker seems stuck**: ask Claude "status?". Claude checks `worker-list` / `worker-read`.
  Claude will not kill a worker unless Orca proves it exited.
- **Claude's session ended mid-task**: start Claude again in the same folder and say
  "continue T-NNN". The brief has the Orca IDs; the worktree and branch are still there.
- **You want to take over by hand**: tell Claude; it retains the worker terminal and steps back.
