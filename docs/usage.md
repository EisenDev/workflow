# How to use the workflow

## Once per machine

```
git clone https://github.com/EisenDev/workflow ~/workspace/Agent-Workflow
~/workspace/Agent-Workflow/scripts/install.sh
systemd-run --user --unit=wf-resource-watch ~/workspace/Agent-Workflow/scripts/resource-watch.sh
```

Start the watcher again after each reboot (or ask Claude to).

## Once per project

```
~/workspace/Agent-Workflow/scripts/wf.sh new <name> "<path to the git repo>" unity|web|software
```

Or tell Claude "add project X at <path>, it's web". Then check `projects/<name>/directory.md`
(see [project-setup.md](project-setup.md)). `wf.sh list` shows all projects.

## Every session

1. Open **Orca**. Open the workflow folder (`~/workspace/Agent-Workflow`) and start Claude there
   (`.claude/settings.json` picks Opus 5.5 at medium effort).
2. Type `/orchestrate` and what you want, for one or many projects:

   ```
   /orchestrate owsi has a bug: the font dropdown resets after saving.
   owsi-giveaway needs a feature: export entries as CSV.
   gemstone-constructions needs optimization: the dashboard loads slowly.
   ```

3. Claude answers with one line per project and asks for the **priority** (it suggests an order).
4. Workers appear in Orca, one worktree per task: Gemini scouts, Codex builds and tests, Gemini
   writes docs and the summary. Watch any terminal, or use the Orca phone app.
5. Claude reports per project: what was done, the test result, **what needs changing before push**,
   Gemini's suggestions, what you should check yourself, then "OK to push?".
6. Answer per project: **OK** (push, PR, merge, archive), **revise: <what>**, **not now**, or
   **drop**.

Also useful: "status", "show the suggestions for owsi", "continue", "dry-run <project>".

## Files in `projects/<name>/`

| File | Meaning |
|---|---|
| `task.md` | the task being worked on; resets to "none" when approved or dropped |
| `archive.md` | finished tasks, newest first: separator, title, outcome, date/time |
| `summary.md` | what the last task did + project state; rewritten after each task |
| `suggestions.md` | Gemini's suggestions; empty when it has none |
| `directory.md` | path, type, base branch, test command, files copied into worktrees |

They stay on your laptop (git-ignored), because this repo is public.

## When something goes wrong

| You see | Do |
|---|---|
| "Queued: waiting for memory" | Close something heavy, or wait. One heavy job runs at a time. |
| "Blocked: out of quota / login" | Top up or log in, then say "continue". |
| Claude's session ended | Start Claude in the workflow folder, say "continue". |
| You want to fix it by hand | Tell Claude; it stops the worker and leaves the worktree to you. |
