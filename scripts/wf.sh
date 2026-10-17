#!/usr/bin/env bash
# Zero-token helpers for the workflow: project files, checks, shipping. Output is kept to a line
# or two so Claude reads a verdict instead of logs and diffs.
#
#   wf.sh list                               one line per project: name, type, priority, status, task
#   wf.sh new <name> <path> <type>           create projects/<name> from the template
#   wf.sh path <name>                        print the project's local path
#   wf.sh prep <worktree>                    create .wf/ (worker notes) and keep it out of git
#   wf.sh check <name> <worktree> [base]     ownership + tests -> one PASS/FAIL line
#   wf.sh collect <name> <worktree>          copy Gemini's .wf/summary.md + suggestions.md in
#   wf.sh archive <name> approved|dropped    move task.md to the top of archive.md, reset task.md
#   wf.sh ship <name> <worktree>             push the task branch, open a PR (summary as body)
#   wf.sh merge <name> <pr>                  squash-merge the PR, archive the task as approved
set -euo pipefail

WF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
P="$WF/projects"

die() { echo "wf: $*" >&2; exit 2; }
proj() { [[ -n "${1:-}" && "$1" != _template && -d "$P/$1" ]] || die "no project '${1:-}' (wf.sh list)"; echo "$P/$1"; }
# field <file> <key>: value of "key: value", ignoring anything inside code fences
field() { awk -v k="$2" '/^```/ {exit} index($0, k ":") == 1 {sub(/^[^:]*:[ \t]*/, ""); print; exit}' "$1"; }
title() { head -n1 "$1/task.md" | sed 's/^# Task: //'; }
project_path() { local p; p=$(field "$1/directory.md" path); echo "${p/#\~/$HOME}"; }
default_branch() { local b; b=$(git -C "$1" rev-parse --abbrev-ref origin/HEAD 2>/dev/null) && echo "${b#origin/}" || echo main; }

cmd_list() {
  local d n
  for d in "$P"/*/; do
    n=$(basename "$d"); [[ "$n" == _template ]] && continue
    printf '%-22s %-9s %-3s %-11s %s\n' "$n" "$(field "$d/directory.md" type)" \
      "$(field "$d/task.md" Priority)" "$(field "$d/task.md" Status || true)" "$(title "$d")"
  done
}

cmd_new() {
  local name="${1:?name}" path="${2:?path}" type="${3:?type}" d test
  [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "name must be lowercase letters, digits, . _ -"
  d="$P/$name"; [[ -e "$d" ]] && die "projects/$name exists"
  path=$(cd "${path/#\~/$HOME}" && pwd) || die "no such folder: $2"
  git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || echo "warn: $path is not a git repo" >&2
  case "$type" in
    unity) test="$WF/scripts/resource-gate.sh run heavy -- unity test . --mode EditMode --output Logs/test-editmode.xml --timeout 3600 -- -nographics" ;;
    *) test="TODO" ;;
  esac
  cp -r "$P/_template" "$d"
  printf '# %s\n\npath: %s\ntype: %s\ntest: %s\n' "$name" "$path" "$type" "$test" > "$d/directory.md"
  echo "created projects/$name ($type, $path)"
}

cmd_prep() {
  local wt="${1:?worktree}" ex
  ex="$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  mkdir -p "$(dirname "$ex")" "$wt/.wf"
  grep -qx '.wf/' "$ex" 2>/dev/null || echo '.wf/' >> "$ex"
}

cmd_check() {
  local d wt="${2:?worktree}" base f p ok rc=0 tests stat dirty
  d=$(proj "${1:-}"); base="${3:-$(default_branch "$wt")}"
  local -a allow outside=() changed
  mapfile -t allow < <(awk '/^## May edit/ {f=1; next} /^## / {f=0} f && /^- / {sub(/^- +/, ""); sub(/[ \t]+$/, ""); print}' "$d/task.md")
  mapfile -t changed < <({ git -C "$wt" diff --name-only "$base"...HEAD
                           git -C "$wt" status --porcelain --untracked-files=all | cut -c4-; } | grep -v '^\.wf/' | sort -u)
  for f in "${changed[@]}"; do
    ok=0
    for p in "${allow[@]}"; do
      if [[ "$p" == */ ]]; then [[ "$f" == "$p"* ]] && ok=1
      else [[ "$f" == $p || "$f" == $p.meta ]] && ok=1; fi   # unquoted: globs allowed
    done
    (( ok )) || outside+=("$f")
  done
  stat=$(git -C "$wt" diff --shortstat "$base"...HEAD | awk '{printf "+%d/-%d", $4, $6}')
  dirty=$(git -C "$wt" status --porcelain | grep -vc '\.wf/' || true)
  tests=$(field "$d/directory.md" test)
  if [[ -z "$tests" || "$tests" == TODO ]]; then tests="tests=none"
  else
    mkdir -p "$wt/.wf"
    (cd "$wt" && bash -c "$tests") > "$wt/.wf/check.log" 2>&1 || rc=$?
    (( rc == 0 )) && tests="tests=ok" || tests="tests=exit-$rc log=$wt/.wf/check.log"
  fi
  local verdict=PASS
  (( rc == 0 && ${#outside[@]} == 0 )) || verdict=FAIL
  echo "$verdict files=${#changed[@]} ${stat:-+0/-0} uncommitted=$dirty $tests${outside:+ outside=$(IFS=,; echo "${outside[*]}")}"
  [[ "$verdict" == PASS ]]
}

cmd_collect() {
  local d wt="${2:?worktree}" n
  d=$(proj "${1:-}")
  if [[ -s "$wt/.wf/summary.md" ]]; then cp "$wt/.wf/summary.md" "$d/summary.md"; else echo "warn: no .wf/summary.md" >&2; fi
  if grep -q '[^[:space:]]' "$wt/.wf/suggestions.md" 2>/dev/null; then
    cp "$wt/.wf/suggestions.md" "$d/suggestions.md"; n=$(grep -c '^- ' "$d/suggestions.md" || true)
    echo "summary updated, suggestions=$n"
  else
    : > "$d/suggestions.md"; echo "summary updated, suggestions=none"
  fi
}

cmd_archive() {
  local d outcome="${2:?approved|dropped}" t tmp
  d=$(proj "${1:-}"); [[ "$outcome" == approved || "$outcome" == dropped ]] || die "outcome: approved|dropped"
  t=$(title "$d"); [[ "$t" == none ]] && die "no active task in projects/$1"
  tmp=$(mktemp)
  {
    head -n3 "$d/archive.md"
    printf '\n---\n\n## %s (%s)\nDone: %s\n' "$t" "$outcome" "$(date '+%F %H:%M')"
    tail -n +2 "$d/task.md" | sed "s/^Status:.*/Status: $outcome/"
    tail -n +4 "$d/archive.md"
  } > "$tmp"
  mv "$tmp" "$d/archive.md"
  cp "$P/_template/task.md" "$d/task.md"
  echo "archived: $t ($outcome)"
}

cmd_ship() {
  local d wt="${2:?worktree}" branch base
  d=$(proj "${1:-}"); branch=$(git -C "$wt" branch --show-current); base=$(default_branch "$wt")
  [[ -n "$branch" && "$branch" != "$base" ]] || die "refusing to ship from '$branch'"
  git -C "$wt" push -q -u origin "$branch"
  (cd "$wt" && gh pr create --base "$base" --head "$branch" --title "$(title "$d")" --body-file "$d/summary.md")
}

cmd_merge() {
  local d pr="${2:?pr number or url}"
  d=$(proj "${1:-}")
  (cd "$(project_path "$d")" && gh pr merge "$pr" --squash --delete-branch)
  cmd_archive "$1" approved
}

c="${1:-}"; shift || true
case "$c" in
  list) cmd_list ;;
  new) cmd_new "$@" ;;
  path) d=$(proj "${1:-}"); project_path "$d" ;;
  prep) cmd_prep "$@" ;;
  check) cmd_check "$@" ;;
  collect) cmd_collect "$@" ;;
  archive) cmd_archive "$@" ;;
  ship) cmd_ship "$@" ;;
  merge) cmd_merge "$@" ;;
  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
