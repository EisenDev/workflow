# Taskflow

How one piece of work goes from the owner's request to a merged PR. Project-independent: the
project type only changes the details pulled from `profiles/<type>.md` and `.agents/project.md`.

Orca (`orca orchestration`, desktop app must be running) is the runtime. It owns worktrees,
starting workers, waiting, messaging and liveness. This file says which command runs at each
step and what Claude checks in between. Written 2026-10-17 against the installed `orca` CLI.

## Roles in the flow

| Who | Orca agent | Does | Never does |
|---|---|---|---|
| Owner | — | Asks, answers gates, approves merge | — |
| Claude (lead, coordinator) | runs in its own terminal | Brief, start workers, review, tests, report, PR, merge | Merge without the owner's OK |
| Codex (builder) | `--agent codex` | Code + tests from a brief, commits on the task branch | Touch files outside the brief's Ownership |
| Gemini (writer) | `--agent antigravity` | Docs, handoff, changelog, long text | Invent decisions, change code |

## Words

- **Run**: one Orca namespace + inbox per owner request (`run-create`). Holds one or more tasks.
- **Task**: one brief, `T-NNN`. Orca gives it a `task_id`; the brief records both.
- **Dispatch**: one attempt at a task by one worker. A retry is a new dispatch, same task.
- **Settled**: Orca received `worker_done` (succeeded or failed) for the dispatch.

## Task states

```
draft -> dispatched -> built -> reviewed -> documented -> reported -> merged
             ^            |        |
             +--rework----+--------+         (any state) -> blocked | abandoned
```

Claude keeps the state in the brief's header line `Status:`.

## Steps

### 0. Preflight (once per session)

```
orca status --json                    # Orca is running, note caller.orcaSessionId
git -C <repo> status                  # clean main, up to date with origin
$WF/scripts/resource-gate.sh status   # memory; start the watcher if it is not running
systemctl --user is-active wf-resource-watch
```

`$WF` = the workflow repo (`$AGENT_WORKFLOW_HOME`, default `~/workspace/Agent-Workflow`).
Memory rules: [docs/resources.md](docs/resources.md).

Read the project's `AGENTS.md`, handoff file, `.agents/project.md` and `profiles/<type>.md`.
Stop and tell the owner if the repo is dirty, not a git repo, or the profile's preflight fails.

### 1. Understand the request

Restate it in one or two sentences. Ask the owner only about real decisions (scope, behaviour,
look). Split into tasks only when the parts can be built and reviewed separately; otherwise one task.

### 2. Write the brief

Copy `templates/task-brief.md` to `.agents/tasks/T-NNN.md` (next free number). Orca's task-spec
contract needs all five of these, so the brief always has them:

| Brief field | Content |
|---|---|
| Target | Files, component or system in scope |
| Change | The concrete result |
| Constraints | Invariants, compatibility, profile rules, forbidden paths |
| Ownership | Exact files/folders this worker may edit; scenes/prefabs it owns (Unity) |
| Acceptance | Test command(s) that must pass + any observable evidence |

Plus: branch `tNNN-<slug>`, report path `.agents/reports/T-NNN.md`, and the worker's closing
instructions (commit, write the report, send `worker_done` with `--report-path`).

### 3. Create the Run and task

```
orca orchestration run-create --objective "<owner request, one line>" --json
orca orchestration task-create --task-title "T-NNN <slug>" --spec "$(cat .agents/tasks/T-NNN.md)" --json
```

Use `--deps '["<task_id>"]'` only for real ordering. Record `run_id` and `task_id` in the brief.

### 4. Start the builder

```
$WF/scripts/resource-gate.sh wait agent      # queue until there is memory; tell the owner if it waits long
orca orchestration worker-start --task <task_id> --agent codex \
  --worktree new-top-level --repo path:<repo> --base-branch main \
  --name tNNN-<slug> --json
```

Optional `--model <id> --effort <level>`. Record `dispatch_id` and the worktree path.
If it exits non-zero: do **not** relaunch. Read `failedStage` / `residualResources` in the
receipt and follow its recovery commands.

### 5. Wait

```
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

Handle every message in the batch, then ack (`check --ack <delivery_id> ...`):

- `question` -> answer with `reply --id <msg_id> --body "..."`. If it is the owner's decision,
  ask the owner first, or use a gate (`gate-create --task <task_id> --question ...`).
- `escalation` -> read it, decide, reply or stop the task and tell the owner.
- `worker_done` -> check it belongs to the expected `dispatch_id`, then go to step 6.

A timeout or empty result is a checkpoint, not a failure. After three empty waits run
`worker-list --json` and act on each row's `projection.nextAction`. Use `worker-read --dispatch <id>`
to see what the worker is doing. Only proof that the process exited allows `worker-stop` / `worker-abandon`.

Out of quota / login expired: shows up as `exited` liveness or an error in `worker-read`.
Mark the task `blocked`, keep the worktree, tell the owner which tool ran out.

### 6. Review (Claude)

In the task worktree:

```
git -C <worktree> log --oneline main..HEAD
git -C <worktree> diff --stat main...HEAD
git -C <worktree> diff main...HEAD
```

Check:

1. Every changed file is inside Ownership; nothing from the forbidden paths list.
2. The change does what the brief says, no more. No unrelated refactors or reformatting.
3. Profile review checklist (e.g. `profiles/unity.md`).
4. Run the project's test command from `.agents/project.md` myself; do not trust the report alone.
   Heavy commands (Unity) go through `resource-gate.sh run unity -- ...`. With
   `test_location: ci|both`, push the task branch and `gh run watch` the test run instead.
5. The report exists and matches the diff.

Fails -> rework:

```
orca orchestration worker-start --task <task_id> --agent codex \
  --worktree path:<worktree> --retry-of <dispatch_id> --json
```

with the review notes added to the brief under `## Rework N`. Back to step 5.
Two failed reworks on the same point -> stop and ask the owner.

For Claude's own code, Codex reviews instead: a review-only task with Ownership "none".

### 7. Docs pass (Gemini)

Only when the task changed behaviour, an interface, setup, or story/text. Small brief: report +
diff summary as input, Ownership = docs/handoff/changelog files only, "describe what was done, do
not invent decisions; write `TODO(owner)` where something is unclear".

```
orca orchestration task-create --task-title "T-NNN docs" --spec "..." --deps '["<task_id>"]' --json
$WF/scripts/resource-gate.sh wait agent
orca orchestration worker-start --task <docs_task_id> --agent antigravity \
  --worktree path:<worktree> --json
```

Then wait as in step 5.

### 8. Check the docs (Claude)

Diff only touches doc files; every statement matches the code or the report; no new decisions.
Fix small things directly, otherwise rework as in step 6.

### 9. Clean up workers

After each accepted `worker_done`, exactly one of: reuse the terminal for the next dispatch,
`worker-retain --dispatch <id>` (owner wants to look), or
`worker-release --dispatch <id>`. Before reporting:

```
orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json   # must be empty
```

### 10. Report to the owner

Plain language, short:

- What changed and why (one paragraph).
- Tests run and result, with the command.
- Anything Claude could not verify (e.g. visuals, play-feel) and how the owner can check it.
- Open `TODO(owner)` items.
- Branch name and "OK to open the PR and merge?"

### 11. PR and merge (only on the owner's OK)

```
git -C <worktree> push -u origin tNNN-<slug>
gh pr create --base main --head tNNN-<slug> --title "T-NNN <title>" --body-file .agents/reports/T-NNN.md
gh pr merge <pr> --squash --delete-branch
orca worktree rm <worktree selector>
git -C <repo> pull
```

Set the brief to `merged`. Without an OK, leave the branch and worktree as they are.

## Rules

- Workers only run inside their task worktree, never the owner's main folder.
- One builder lane (Codex) and one writer lane (Gemini) until the flow has proven itself.
- No worker starts and no Unity run starts without passing `resource-gate.sh`.
- Every task has exactly one outcome in the final report: merged, waiting for OK, blocked or abandoned.
- Nothing gets merged to main without the owner's OK.
- Never delete a worktree or branch that has unmerged work without asking.

## To verify in the first end-to-end test

- Whether `worker-start --name tNNN-<slug>` also names the git branch, or the branch must be set
  separately (`orca worktree create --help`).
- How to choose the Gemini model (`gemini-4-argon-medium`) for `--agent antigravity`: `--model`
  officially supports only Claude/Codex/Cursor IDs; may need Orca's per-agent default setting.
- Whether Codex commits by itself or Claude must commit after review.
- Exact `--repo` / `--worktree` selector strings for this machine (`orca worktree list --json`).
