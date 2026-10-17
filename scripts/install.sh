#!/usr/bin/env bash
# Link this repo's skills into each tool's skill folder (same pattern as the existing skills:
# a real folder per skill with SKILL.md symlinked). Safe to rerun.
set -euo pipefail

WF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

link_skill() {
  local skill="$1" dest_root="$2"
  local dest="$dest_root/$skill"
  mkdir -p "$dest"
  if [[ -e "$dest/SKILL.md" && ! -L "$dest/SKILL.md" ]]; then
    echo "skip: $dest/SKILL.md is a real file, not ours" >&2
    return
  fi
  ln -sfn "$WF/skills/$skill/SKILL.md" "$dest/SKILL.md"
  echo "linked $skill -> $dest"
}

link_skill orchestrate      "$HOME/.claude/skills"
link_skill workflow-builder "$HOME/.codex/skills"
link_skill workflow-writer  "$HOME/.agents/skills"   # read by agy (verify)

if [[ "$WF" != "$HOME/workspace/Agent-Workflow" ]]; then
  echo "note: add 'export AGENT_WORKFLOW_HOME=\"$WF\"' to your shell profile"
fi
