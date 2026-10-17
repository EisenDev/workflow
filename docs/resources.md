# Memory: queue, cap, freeze

The laptop has 15 GiB RAM + 8 GiB zram swap. Agent CLIs use ~0.3–0.5 GiB each; Unity imports and
tests, Playwright browsers and builds use several GiB. So: **agents queue, heavy jobs run one at a
time, capped, and can be frozen.** Everything runs locally; there is no GitHub Actions part.

btop is a viewer; the scripts read the same numbers btop shows: free memory (`MemAvailable`) and
memory pressure (`/proc/pressure/memory`). Keep btop open to watch; the scripts act.

## The pieces

| Piece | What it does |
|---|---|
| `resource-gate.sh status` | One line: level, free memory, swap, pressure, heavy jobs, frozen jobs |
| `resource-gate.sh wait agent` | Before every worker start. Waits until ≥ 3 GiB free and pressure < 10%. |
| `resource-gate.sh run heavy -- <cmd>` | Every Unity/Playwright/build command. One at a time (lock), waits for ≥ 6 GiB free, runs in its own systemd scope capped at 6 GiB (throttled) / 8 GiB (killed: the job dies, not your desktop). |
| `resource-watch.sh` | Background watcher. Free < 1.5 GiB → freezes the newest heavy job (paused, nothing lost). Free ≥ 6 GiB → thaws it. Logs to `~/.local/state/agent-workflow/resource.log`. |

Agents are queued, never frozen: an agent mid-answer holds a live API connection, and freezing it
can break the session.

## Priority

Claude starts the highest-priority project's workers first. Lower-priority workers and heavy jobs
wait at the gate; nothing is cancelled.

## Watcher

```
systemd-run --user --unit=wf-resource-watch ~/workspace/Agent-Workflow/scripts/resource-watch.sh
systemctl --user is-active wf-resource-watch
systemctl --user stop wf-resource-watch
```

Not persistent: start it again after a reboot.

## Tuning (environment variables, defaults in `resource-gate.sh`)

| Variable | Default | Meaning |
|---|---|---|
| `WF_MIN_FREE_AGENT` | 3 | GiB free to start an agent |
| `WF_MIN_FREE_HEAVY` | 6 | GiB free to start or thaw a heavy job |
| `WF_CRITICAL_FREE` | 1.5 | GiB free below which a heavy job is frozen |
| `WF_MAX_PSI` | 10 | memory pressure % above which nothing new starts |
| `WF_HEAVY_MEMORY_HIGH` / `_MAX` | 6G / 8G | per-job cap |
| `WF_POLL` | 15 | seconds between checks |

A frozen job's time still counts against its own timeout (`unity test --timeout`); the Unity
profile uses 3600 s for that reason.
