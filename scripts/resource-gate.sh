#!/usr/bin/env bash
# Memory gate: queue new agents / Unity runs while the machine is short on memory, and run Unity
# jobs in a memory-capped systemd scope that resource-watch.sh can freeze. Reads the numbers btop
# shows (/proc/meminfo MemAvailable, /proc/pressure/memory).
#
#   resource-gate.sh status [--json]
#   resource-gate.sh check agent|unity          exit 0 = go, 1 = wait
#   resource-gate.sh wait  agent|unity [secs]   block until go (default 3600 s; 0 = forever)
#   resource-gate.sh run   unity -- <cmd...>    one Unity job at a time, capped, then <cmd>
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agent-workflow"
mkdir -p "$STATE"
LOG="$STATE/resource.log"

# Thresholds; override with env vars. GiB unless noted.
: "${WF_MIN_FREE_AGENT:=3}"      # free memory needed to start an agent
: "${WF_MIN_FREE_UNITY:=6}"      # free memory needed to start a Unity run
: "${WF_CRITICAL_FREE:=1.5}"     # below this the watcher freezes Unity jobs
: "${WF_MAX_PSI:=10}"            # memory pressure "some avg10" (%) above this = busy
: "${WF_UNITY_MEMORY_HIGH:=6G}"  # Unity job is throttled above this
: "${WF_UNITY_MEMORY_MAX:=8G}"   # and killed above this, instead of the desktop
: "${WF_POLL:=15}"               # seconds between checks

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG" >&2; }

mem_avail() { awk '/^MemAvailable:/ {printf "%.2f", $2/1048576}' /proc/meminfo; }
swap_used() { awk '/^SwapTotal:/ {t=$2} /^SwapFree:/ {f=$2} END {printf "%.2f", (t-f)/1048576}' /proc/meminfo; }
psi() { awk -v k="$1" '$1==k {split($2,a,"="); print a[2]}' /proc/pressure/memory; }
lt() { awk -v a="$1" -v b="$2" 'BEGIN {exit !(a < b)}'; }

unity_units() {
  systemctl --user list-units --type=scope --no-legend --plain 'wf-unity-*' 2>/dev/null | awk '{print $1}'
}
frozen_units() {
  local u
  for u in $(unity_units); do
    [[ "$(systemctl --user show -p FreezerState --value "$u")" == frozen ]] && echo "$u"
  done
  return 0
}

need_for() {
  case "$1" in
    agent) echo "$WF_MIN_FREE_AGENT" ;;
    unity) echo "$WF_MIN_FREE_UNITY" ;;
    *) echo "unknown kind: $1 (agent|unity)" >&2; exit 2 ;;
  esac
}

level() {
  local avail p
  avail=$(mem_avail); p=$(psi some)
  if lt "$avail" "$WF_CRITICAL_FREE"; then echo critical
  elif ! lt "$p" "$WF_MAX_PSI"; then echo busy
  else echo ok
  fi
}

# Exit 0 if a new job of this kind may start; prints the reason otherwise.
check() {
  local need avail p
  need=$(need_for "$1"); avail=$(mem_avail); p=$(psi some)
  if lt "$avail" "$need"; then echo "need ${need} GiB free, have ${avail}"; return 1; fi
  if ! lt "$p" "$WF_MAX_PSI"; then echo "memory pressure ${p}% >= ${WF_MAX_PSI}%"; return 1; fi
  if [[ -n "$(frozen_units)" ]]; then echo "a Unity job is frozen for memory"; return 1; fi
  return 0
}

wait_for() {
  local kind="$1" timeout="${2:-3600}" start reason first=1
  start=$(date +%s)
  until reason=$(check "$kind"); do
    if (( first )); then log "queued $kind: $reason"; first=0; fi
    if (( timeout > 0 && $(date +%s) - start >= timeout )); then
      log "gave up waiting for $kind after ${timeout}s: $reason"; return 1
    fi
    sleep "$WF_POLL"
  done
  (( first )) || log "released $kind after $(( $(date +%s) - start ))s"
}

run_unity() {
  exec 9>"$STATE/unity.lock"
  if ! flock -n 9; then log "queued unity: another Unity job is running"; flock 9; fi
  wait_for unity 0
  local unit="wf-unity-$(date +%s)-$$"
  if systemd-run --user --scope -q true 2>/dev/null; then
    log "start $unit: $*"
    exec systemd-run --user --scope --collect -q --unit "$unit" \
      -p MemoryHigh="$WF_UNITY_MEMORY_HIGH" -p MemoryMax="$WF_UNITY_MEMORY_MAX" -- "$@"
  fi
  log "start (no systemd scope, not capped): $*"
  exec "$@"
}

status() {
  local avail swap s f units frozen
  avail=$(mem_avail); swap=$(swap_used); s=$(psi some); f=$(psi full)
  units=$(unity_units | wc -l); frozen=$(frozen_units | wc -l)
  if [[ "${1:-}" == --json ]]; then
    printf '{"level":"%s","mem_available_gib":%s,"swap_used_gib":%s,"psi_some_avg10":%s,"psi_full_avg10":%s,"unity_jobs":%d,"unity_frozen":%d}\n' \
      "$(level)" "$avail" "$swap" "$s" "$f" "$units" "$frozen"
  else
    echo "level=$(level) free=${avail}GiB swap_used=${swap}GiB pressure=${s}%/${f}% unity_jobs=$units frozen=$frozen"
  fi
}

cmd="${1:-status}"; shift || true
case "$cmd" in
  status) status "$@" ;;
  check)  need_for "${1:?kind}" >/dev/null; check "$1" ;;
  wait)   need_for "${1:?kind}" >/dev/null; wait_for "$1" "${2:-3600}" ;;
  run)
    [[ "${1:-}" == unity && "${2:-}" == -- ]] || { echo "usage: run unity -- <cmd...>" >&2; exit 2; }
    shift 2; run_unity "$@" ;;
  *) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
