# Memory: queue, cap, freeze, offload

The laptop has 15 GiB RAM + 8 GiB zram swap. Agent CLIs use ~0.3–0.5 GiB each; a Unity editor
import or test run uses several GiB. So the rule is: **agents queue, Unity runs one at a time,
capped, and can be frozen; heavy test runs can go to GitHub Actions.**

btop is a viewer; the scripts read the same numbers btop shows: free memory (`MemAvailable`) and
memory pressure (`/proc/pressure/memory`, the % of time programs wait for memory). Keep btop open
to watch; the scripts act.

## The pieces

| Piece | What it does |
|---|---|
| `scripts/resource-gate.sh status` | One line: level, free memory, swap, pressure, Unity jobs, frozen jobs |
| `scripts/resource-gate.sh wait agent` | Claude runs it before every `worker-start`. Blocks (queues) until ≥ 3 GiB free and pressure < 10%. |
| `scripts/resource-gate.sh run unity -- <cmd>` | Every Unity batch run goes through this: one at a time (lock), waits for ≥ 6 GiB free, runs in its own systemd scope capped at 6 GiB (throttled) / 8 GiB (killed — Unity dies, not your desktop). |
| `scripts/resource-watch.sh` | Background watcher. Free < 1.5 GiB → freezes the newest Unity job (paused, nothing lost). Free ≥ 6 GiB again → thaws it. Logs and notifies. |
| GitHub Actions (`templates/github/unity-tests.yml`) | Runs Unity tests on GitHub's machines instead of the laptop. |

Why agents are queued but not frozen: an agent CLI holds a live connection to its API; freezing it
mid-answer can break the session. A Unity batch job has no such problem.

## Start the watcher (once per login)

```
systemd-run --user --unit=wf-resource-watch ~/workspace/Agent-Workflow/scripts/resource-watch.sh
systemctl --user status wf-resource-watch      # running?
systemctl --user stop wf-resource-watch        # stop
```

Log: `~/.local/state/agent-workflow/resource.log`.

## Tuning

All thresholds are environment variables (defaults in `resource-gate.sh`):

| Variable | Default | Meaning |
|---|---|---|
| `WF_MIN_FREE_AGENT` | 3 | GiB free to start an agent |
| `WF_MIN_FREE_UNITY` | 6 | GiB free to start or thaw a Unity job |
| `WF_CRITICAL_FREE` | 1.5 | GiB free below which a Unity job is frozen |
| `WF_MAX_PSI` | 10 | memory pressure % above which nothing new starts |
| `WF_UNITY_MEMORY_HIGH` / `_MAX` | 6G / 8G | per-Unity-job cap |
| `WF_POLL` | 15 | seconds between checks |

A frozen job's time still counts against `unity test --timeout`; the profile uses 3600 s for that
reason.

## Local or GitHub Actions?

Set per project in `.agents/project.md`:

| `test_location` | Who runs the tests | Use when |
|---|---|---|
| `local` | Worker and Claude, through the gate | Small project, fast tests |
| `ci` | GitHub Actions only; workers skip Unity runs | Big imports, low memory, or many tasks |
| `both` | Worker runs a quick filtered local run; Claude waits for CI as the real check | Default for Unity once CI is set up |

With `ci`/`both`, Claude pushes the **task branch** (not main) to trigger the run and waits with
`gh run watch`. That push is allowed by setting `test_location`; merging still needs the owner's OK.

Costs: public repos get free Actions minutes on standard runners; private repos use the account's
monthly quota. Unity in CI needs a Unity license stored as repo secrets (see the template).
