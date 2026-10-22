#!/usr/bin/env bash
# Link this repo's skills into each tool's skill folder (same pattern as the existing skills:
# a real folder per skill with SKILL.md symlinked). Safe to rerun.
set -euo pipefail

WF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

link_skill() {
  local skill="$1" dest_root="$2" name="${3:-$1}"   # name: folder name the tool sees
  local dest="$dest_root/$name"
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
link_skill workflow-writer  "$HOME/.agents/skills"
# agy 1.4 loads skills from ~/.gemini/config/skills only (seen in its logs)
link_skill workflow-writer  "$HOME/.gemini/config/skills"
link_skill orchestrate-solo "$HOME/.gemini/config/skills" orchestrate   # /orchestrate in agy

if [[ "$WF" != "$HOME/workspace/Agent-Workflow" ]]; then
  echo "note: add 'export AGENT_WORKFLOW_HOME=\"$WF\"' to your shell profile"
fi
