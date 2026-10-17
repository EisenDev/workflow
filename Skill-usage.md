# How to use the workflow

## Once per machine

```
git clone https://github.com/EisenDev/workflow ~/workspace/Agent-Workflow
~/workspace/Agent-Workflow/scripts/install.sh
systemd-run --user --unit=wf-resource-watch ~/workspace/Agent-Workflow/scripts/resource-watch.sh
```

The watcher must be started again after each reboot (or ask Claude to start it).

## Once per project

```
~/workspace/Agent-Workflow/scripts/wf.sh new solbeast ~/workspace/solbeast unity
```

Creates `projects/solbeast/` with `directory.md` (path, type, test command), `task.md`,
`archive.md`, `summary.md`, `suggestions.md`. Or just tell Claude "add project solbeast at
~/workspace/solbeast, it's Unity". Check the `test:` line in `directory.md` once.

## Every session

1. Open **Orca**. Open the **workflow folder** (`~/workspace/Agent-Workflow`) and start Claude
   there. The project settings in `.claude/settings.json` choose Opus 5.5 at medium effort.
2. Tell Claude what you want, for one or many projects:

   ```
   /orchestrate solbeast has a bug: the player falls through the floor after respawn.
   owsi needs a new feature: export the inventory as CSV.
   gemstone-development needs optimization: the main menu takes 8 seconds to load.
   ```

3. Claude answers with one line per project and **asks for the priority** (it suggests an order).
4. Workers appear in Orca as their own terminals per project: Gemini scouts, Codex builds and
   tests, Gemini writes docs and the summary. You can watch any of them, or the Orca phone app.
5. Claude reports per project: what was done, test result, **what needs changing before push**,
   Gemini's suggestions, what you should check yourself. Then: "OK to push?"
6. You answer per project: **OK** (push, PR, merge, archive), **revise: <what>** (back to Codex),
   **not now** (stays waiting), or **drop** (archived as dropped).

Other things you can say: "status" (Claude runs `wf.sh list`), "show the suggestions for owsi",
"pause gemstone", "continue T-004".

## What you see in `projects/<name>/`

| File | Meaning |
|---|---|
| `task.md` | the task being worked on now; resets to "none" when it is approved or dropped |
| `archive.md` | every finished task, newest first, with `---` separator, title, outcome, date/time |
| `summary.md` | what the last task did and the project's state; rewritten after each task |
| `suggestions.md` | Gemini's suggestions; empty when it has none |
| `directory.md` | where the project is on this laptop, its type and test command |

These folders stay on your laptop (git-ignored), because the workflow repo is public.

## When something goes wrong

| You see | Do |
|---|---|
| "Queued: waiting for memory" | Close something heavy, or wait. One heavy job runs at a time. |
| "Blocked: Codex out of quota / login" | Top up or log in, then say "continue". |
| Claude's session closed mid-task | Start Claude in the workflow folder, say "continue". It reads `wf.sh list` and the task files. |
| You want to fix it by hand | Tell Claude; it stops the worker and leaves the worktree to you. |
