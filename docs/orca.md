# Orca cheat sheet

The Orca commands this workflow uses. Checked against the installed `orca` CLI on 2026-10-17.
Full guide: `orca skills get orchestration`. Every command takes `--json`. The Orca desktop app
must be running.

## Concepts

| Orca | In our workflow |
|---|---|
| Run | One owner request. Namespace + inbox for Claude. |
| Task | One task (`projects/<name>/task.md`), `T-NNN`. |
| Dispatch | One attempt at a task by one worker. Retry = new dispatch. |
| `worker_done` | The worker's "finished" message. Settles the dispatch. |
| Gate | A question that blocks a task until someone resolves it. |

## Coordinator (Claude)

```
orca status --json
orca orchestration run-create --objective "<request>" --json
orca orchestration task-create --task-title "T-NNN <slug>" --spec "<task.md text>" [--deps '["<task_id>"]'] --json
orca orchestration worker-start --task <task_id> --agent codex|antigravity|claude \
    --worktree new-top-level|path:<p>|branch:<b>|current [--repo path:<repo>] \
    [--base-branch main] [--name <name>] [--model <id> --effort <level>] [--retry-of <dispatch_id>] --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
orca orchestration check --ack <delivery_id> ...            # after handling every message in the batch
orca orchestration reply --id <msg_id> --body "<answer>" --json
orca orchestration send --to dispatch:<id> --subject "<s>" --body "<guidance>" --json
orca orchestration gate-create --task <task_id> --question "<q>" [--options '["a","b"]'] --json
orca orchestration gate-resolve --id <gate_id> --resolution "<answer>" --json
```

## Watching workers

```
orca orchestration worker-list [--run <run_id>] [--terminal-state reclaimable] --json
orca orchestration worker-show --dispatch <id> --json
orca orchestration worker-read --dispatch <id> [--limit <n>] --json
orca worktree ps
```

Liveness: `live`, `unverifiable` (no proof either way; keep waiting), `exited`.

## Cleanup

```
orca orchestration worker-release --dispatch <id> --json   # after accepted worker_done
orca orchestration worker-retain  --dispatch <id> --json   # owner wants to look
orca orchestration worker-stop    --dispatch <id> --json   # only with proof it must stop
orca worktree rm <selector>                                 # after merge
```

## Worker side (in the preamble Orca injects)

```
orca orchestration ask --question "<q>" [--options "a,b"] --json
orca orchestration check --terminal <handle> --json
orca orchestration send --type worker_done --outcome succeeded|failed \
    --task-id <t> --dispatch-id <d> --files-modified "<a,b>" --report-path <p> ...
```

Use the exact form the preamble gives; do not rebuild the IDs.

## Repo setup hooks: `orca.yaml`

```yaml
scripts:
  setup: |      # runs when Orca creates a worktree
    <commands>
  archive: |    # runs when a worktree is removed
    <commands>
```
