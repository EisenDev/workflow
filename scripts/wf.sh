#!/usr/bin/env bash
# Zero-token helpers for the workflow: project files, checks, shipping. Output is kept to a line
# or two so Claude reads a verdict instead of logs and diffs.
#
#   wf.sh list                               one line per project: name, type, priority, status, task
#   wf.sh new <name> <path> <type>           create projects/<name> from the template
#   wf.sh path <name>                        print the project's local path
#   wf.sh prep <name> <worktree>             create .wf/, keep it out of git, copy local files in
#   wf.sh map-status <name>                  is codemap.md current? lists files changed since it was made
#   wf.sh map-stamp <name>                   mark codemap.md as current (base branch tip, date)
#   wf.sh diff <name> <worktree>             the task's code changes (no lock files, .meta, binaries)
#   wf.sh writer-check                       is Gemini 4 Argon available? else the lead writes
#   wf.sh check <name> <worktree> [base]     ownership + tests -> one PASS/FAIL line
#   wf.sh collect <name> <worktree>          copy Gemini's .wf/summary.md + suggestions.md in
#   wf.sh archive <name> approved|dropped    move task.md to the top of archive.md, reset task.md
#   wf.sh ship <name> <worktree>             push the task branch, open a PR (summary as body)
#   wf.sh merge <name> <pr>                  squash-merge the PR, archive the task as approved
#   wf.sh deploy <name>                      deploy origin/<base> to production (directory.md deploy:)
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
# base <project dir> <git dir>: branch tasks start from (directory.md base:, else origin/HEAD)
base_branch() { local b; b=$(field "$1/directory.md" base); [[ -n "$b" ]] && echo "$b" || default_branch "$2"; }

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
  local base=""
  if git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then base=$(default_branch "$path")
  else echo "warn: $path is not a git repo; tasks cannot run until it is" >&2; fi
  case "$type" in
    unity) test="$WF/scripts/resource-gate.sh run heavy -- unity test . --mode EditMode --output Logs/test-editmode.xml --timeout 3600 -- -nographics" ;;
    *) test="TODO" ;;
  esac
  cp -r "$P/_template" "$d"
  printf '# %s\n\npath: %s\ntype: %s\nbase: %s\ntest: %s\ncopy:\n' "$name" "$path" "$type" "$base" "$test" > "$d/directory.md"
  echo "created projects/$name ($type, $path)"
}

# ref <project dir>: the base branch tasks start from (local branch, else origin/<base>)
base_ref() {
  local d="$1" path b
  path=$(project_path "$d"); b=$(base_branch "$d" "$path")
  git -C "$path" rev-parse -q --verify "refs/heads/$b" >/dev/null && echo "$b" || echo "origin/$b"
}

cmd_map_status() {
  local d path ref mapped head n files dirty
  d=$(proj "${1:-}"); path=$(project_path "$d")
  git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || die "$path is not a git repo"
  git -C "$path" fetch -q origin 2>/dev/null || echo "warn: fetch failed, comparing local refs" >&2
  ref=$(base_ref "$d"); head=$(git -C "$path" rev-parse --short "$ref")
  dirty=$(git -C "$path" status --porcelain | wc -l)
  mapped=$(sed -n 's/^Mapped: \([0-9a-f]\{7,40\}\).*/\1/p' "$d/codemap.md" 2>/dev/null | head -n1 || true)
  local sync=""
  if [[ "$ref" != origin/* ]] && git -C "$path" rev-parse -q --verify "origin/$ref" >/dev/null; then
    sync=", vs origin: $(git -C "$path" rev-list --left-right --count "$ref...origin/$ref" | awk '{print "ahead " $1 " behind " $2}')"
  fi
  dirty="$dirty$sync"
  if [[ -z "$mapped" ]]; then echo "missing: no codemap yet (base $ref at $head, main folder uncommitted=$dirty)"; return 1; fi
  if ! git -C "$path" cat-file -e "$mapped^{commit}" 2>/dev/null; then echo "missing: mapped commit $mapped not found; remap"; return 1; fi
  n=$(git -C "$path" rev-list --count "$mapped..$ref")
  if (( n == 0 )); then echo "fresh: codemap at $head ($ref), main folder uncommitted=$dirty"; return 0; fi
  files=$(git -C "$path" diff --name-only "$mapped" "$ref" | grep -vE '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$|\.meta$' || true)
  echo "stale: $n commit(s) since $mapped -> $head ($ref); $(wc -l <<< "$files") file(s) changed, main folder uncommitted=$dirty"
  head -n 40 <<< "$files" | sed 's/^/  /'
  (( $(wc -l <<< "$files") > 40 )) && echo "  ... (more: git -C \"$path\" diff --stat $mapped $ref)"
  return 1
}

cmd_map_stamp() {
  local d path ref sha tmp
  d=$(proj "${1:-}"); path=$(project_path "$d"); ref=$(base_ref "$d")
  sha=$(git -C "$path" rev-parse --short=12 "$ref")
  [[ -f "$d/codemap.md" ]] || die "no codemap.md to stamp"
  tmp=$(mktemp)
  if grep -q '^Mapped: ' "$d/codemap.md"; then
    sed "s|^Mapped: .*|Mapped: $sha on $ref at $(date '+%F %H:%M')|" "$d/codemap.md" > "$tmp"
  else
    { head -n1 "$d/codemap.md"; echo; echo "Mapped: $sha on $ref at $(date '+%F %H:%M')"; tail -n +2 "$d/codemap.md"; } > "$tmp"
  fi
  mv "$tmp" "$d/codemap.md"; echo "codemap stamped at $sha ($ref)"
}

cmd_diff() {
  local d wt="${2:?worktree}" base
  d=$(proj "${1:-}"); base=$(base_branch "$d" "$wt")
  git -C "$wt" log --oneline "$base"..HEAD
  git -C "$wt" diff --stat "$base"...HEAD | tail -n1
  git -C "$wt" diff "$base"...HEAD -- . ':(exclude)package-lock.json' ':(exclude)pnpm-lock.yaml' \
    ':(exclude)yarn.lock' ':(exclude)*.meta' ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.fbx'
}

# Gemini 4 Argon must be listed and be agy's default model; otherwise the lead writes.
cmd_writer_check() {
  local want="${WF_WRITER_MODEL:-gemini-4-argon-high}" cfg="$HOME/.gemini/antigravity-cli/settings.json" def
  command -v agy >/dev/null || { echo "writer=claude (agy not installed)"; return 1; }
  timeout 30 agy models 2>/dev/null | grep -q "^$want\b" || { echo "writer=claude ($want not available)"; return 1; }
  def=$(sed -n 's/.*"model": *"\([^"]*\)".*/\1/p' "$cfg" 2>/dev/null | head -n1)
  [[ "$def" == *Argon* ]] || echo "warn: agy default model is '${def:-unset}', not Argon" >&2
  echo "writer=gemini ($want; agy default: ${def:-unset})"
}

cmd_prep() {
  local d wt="${2:?worktree}" ex src f n=0
  d=$(proj "${1:-}")
  ex="$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  mkdir -p "$(dirname "$ex")" "$wt/.wf"
  grep -qx '.wf/' "$ex" 2>/dev/null || echo '.wf/' >> "$ex"
  # copy: comma-separated paths (git-ignored local files such as .env.local) copied if missing
  src=$(project_path "$d")
  IFS=, read -ra files <<< "$(field "$d/directory.md" copy)"
  for f in "${files[@]}"; do
    f="${f#"${f%%[![:space:]]*}"}"; f="${f%"${f##*[![:space:]]}"}"; [[ -z "$f" ]] && continue
    [[ -e "$src/$f" ]] || { echo "warn: copy: $f not found in project" >&2; continue; }
    [[ -e "$wt/$f" ]] || { mkdir -p "$(dirname "$wt/$f")"; cp -a "$src/$f" "$wt/$f"; n=$((n + 1)); }
  done
  trust_agy "$wt"
  echo "prepared $wt (.wf/ excluded, copied $n file(s), trusted for agy)"
}

# agy trusts exact paths only (a trusted parent does not count): add the worktree so a worker
# never stops at "Do you trust the contents of this project?".
trust_agy() {
  local wt s="${WF_AGY_SETTINGS:-$HOME/.gemini/antigravity-cli/settings.json}" tmp
  wt=$(cd "$1" && pwd -P)
  [[ -f "$s" ]] || { echo "warn: $s not found; agy trust not set" >&2; return 0; }
  jq -e --arg p "$wt" '(.trustedWorkspaces // []) | index($p)' "$s" >/dev/null && return 0
  tmp=$(mktemp "$s.XXXX")
  jq --arg p "$wt" '.trustedWorkspaces = ((.trustedWorkspaces // []) + [$p])' "$s" > "$tmp" && mv "$tmp" "$s"
}

cmd_check() {
  local d wt="${2:?worktree}" base f p ok rc=0 tests stat dirty
  d=$(proj "${1:-}"); base="${3:-$(base_branch "$d" "$wt")}"
  local -a allow outside=() changed
  mapfile -t allow < <(awk '/^## May edit/ {f=1; next} /^## / {f=0} f && /^- / {sub(/^- +/, ""); sub(/[ \t]+$/, ""); print}' "$d/task.md")
  mapfile -t changed < <({ git -C "$wt" diff --name-only "$base"...HEAD
                           git -C "$wt" status --porcelain --untracked-files=all | cut -c4-; } | grep -v '^\.wf/' | sort -u)
  for f in "${changed[@]}"; do
    ok=0
    for p in "${allow[@]}"; do
      if [[ "$p" == */ ]]; then [[ "$f" == "$p"* ]] && ok=1
      # literal match first (Next.js paths like [id] are not globs), then glob match
      elif [[ "$f" == "$p" || "$f" == "$p.meta" || "$f" == $p || "$f" == $p.meta ]]; then ok=1; fi
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
  d=$(proj "${1:-}"); branch=$(git -C "$wt" branch --show-current); base=$(base_branch "$d" "$wt")
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

# deploy: vercel -> `vercel deploy --prod` from a clean checkout of origin/<base>, so no local
# .env file, untracked file or other branch is uploaded. Only on the owner's OK.
cmd_deploy() {
  local d src base kind wt
  d=$(proj "${1:-}"); src=$(project_path "$d"); base=$(base_branch "$d" "$src")
  kind=$(field "$d/directory.md" deploy)
  [[ "$kind" == vercel ]] || die "deploy: '$kind' not supported (directory.md deploy: vercel)"
  [[ -f "$src/.vercel/project.json" ]] || die "no .vercel/project.json in $src (run vercel link there)"
  git -C "$src" fetch -q origin "$base"
  wt="${XDG_CACHE_HOME:-$HOME/.cache}/agent-workflow/deploy/$(basename "$d")"
  git -C "$src" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
  git -C "$src" worktree add -q --detach "$wt" "origin/$base"
  mkdir -p "$wt/.vercel"; cp "$src/.vercel/project.json" "$wt/.vercel/"
  echo "deploying origin/$base @ $(git -C "$wt" rev-parse --short HEAD) to production"
  (cd "$wt" && vercel deploy --prod --yes) || { git -C "$src" worktree remove --force "$wt"; die "deploy failed"; }
  git -C "$src" worktree remove --force "$wt"
}

c="${1:-}"; shift || true
case "$c" in
  list) cmd_list ;;
  new) cmd_new "$@" ;;
  path) d=$(proj "${1:-}"); project_path "$d" ;;
  prep) cmd_prep "$@" ;;
  map-status) cmd_map_status "$@" ;;
  map-stamp) cmd_map_stamp "$@" ;;
  diff) cmd_diff "$@" ;;
  writer-check) cmd_writer_check ;;
  check) cmd_check "$@" ;;
  collect) cmd_collect "$@" ;;
  archive) cmd_archive "$@" ;;
  ship) cmd_ship "$@" ;;
  deploy) cmd_deploy "$@" ;;
  merge) cmd_merge "$@" ;;
  *) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
