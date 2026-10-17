#!/usr/bin/env bash
# Watcher: when free memory drops below WF_CRITICAL_FREE, freeze the newest running heavy job (Unity, Playwright, build)
# (cgroup freeze, nothing is lost); when memory is back above WF_MIN_FREE_HEAVY, thaw one.
# Agent CLIs are never frozen: they hold live API connections. New agents are queued by
# resource-gate.sh instead. Start it once per login:
#   systemd-run --user --unit=wf-resource-watch ~/workspace/Agent-Workflow/scripts/resource-watch.sh
set -euo pipefail

GATE="$(dirname "$(readlink -f "$0")")/resource-gate.sh"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agent-workflow"
mkdir -p "$STATE"
LOG="$STATE/resource.log"
: "${WF_CRITICAL_FREE:=1.5}"
: "${WF_MIN_FREE_HEAVY:=6}"
: "${WF_POLL:=15}"

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"
  command -v notify-send >/dev/null && notify-send -a agent-workflow "Agent workflow" "$*" 2>/dev/null || true
}
mem_avail() { awk '/^MemAvailable:/ {printf "%.2f", $2/1048576}' /proc/meminfo; }
lt() { awk -v a="$1" -v b="$2" 'BEGIN {exit !(a < b)}'; }
units_by_state() {  # $1 = frozen|running; unit names sort oldest first (epoch in the name)
  local u
  for u in $(systemctl --user list-units --type=scope --no-legend --plain 'wf-heavy-*' | awk '{print $1}' | sort); do
    [[ "$(systemctl --user show -p FreezerState --value "$u")" == "$1" ]] && echo "$u"
  done
  return 0
}

log "watcher started (freeze heavy jobs < ${WF_CRITICAL_FREE} GiB, thaw >= ${WF_MIN_FREE_HEAVY} GiB)"
while true; do
  avail=$(mem_avail)
  if lt "$avail" "$WF_CRITICAL_FREE"; then
    u=$(units_by_state running | tail -n1)
    if [[ -n "$u" ]] && systemctl --user freeze "$u"; then
      log "froze $u: only ${avail} GiB free ($("$GATE" status))"
    fi
  elif ! lt "$avail" "$WF_MIN_FREE_HEAVY"; then
    u=$(units_by_state frozen | head -n1)
    if [[ -n "$u" ]] && systemctl --user thaw "$u"; then
      log "thawed $u: ${avail} GiB free"
    fi
  fi
  sleep "$WF_POLL"
done
