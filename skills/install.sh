#!/usr/bin/env sh
# Install an Enprompta Agent Skill into your coding agent.
#
# The skills follow the open Agent Skills standard (https://agentskills.io) — a
# folder with a SKILL.md, plain markdown, no agent-specific code. Any compatible
# agent (Claude Code, Cursor, Codex, Copilot, Gemini CLI, OpenCode, Goose, …)
# loads them from a skills directory; this script copies the folder there.
#
# Usage:
#   skills/install.sh [skill] [--user|--project] [--dir <path>]
#
#   skill        enprompta-instrumentation | enprompta | all   (default: all)
#   --user       install to ~/.claude/skills/            (personal, all projects)
#   --project    install to ./.claude/skills/            (this repo only) [default]
#   --dir <path> install to an explicit skills directory (for any other agent —
#                see your agent's docs / agentskills.io for its skills location)
#
# Examples:
#   skills/install.sh                                   # both skills, project scope
#   skills/install.sh enprompta-instrumentation --user  # tracing setup, user scope
#   skills/install.sh all --dir ~/.cursor/skills        # target another agent
set -eu

SRC_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

skill="all"
dest=".claude/skills"

while [ $# -gt 0 ]; do
  case "$1" in
    enprompta-instrumentation|enprompta|all) skill="$1" ;;
    --user)    dest="$HOME/.claude/skills" ;;
    --project) dest=".claude/skills" ;;
    --dir)     shift; dest="${1:?--dir needs a path}" ;;
    # Print the header comment, stopping at the first line that isn't one.
    # A hardcoded line range drifts the moment the header changes length.
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

install_one() {
  name="$1"
  if [ ! -d "$SRC_DIR/$name" ]; then
    echo "No such skill: $name" >&2; exit 1
  fi
  mkdir -p "$dest"
  # Replace, don't merge. `cp -R` into an existing directory leaves behind
  # files that were deleted upstream, so a reference/ page we retired would
  # keep being read by every agent that had already installed it.
  rm -rf "$dest/$name"
  cp -R "$SRC_DIR/$name" "$dest/"
  echo "Installed '$name' -> $dest/$name"
}

case "$skill" in
  all) install_one enprompta-instrumentation; install_one enprompta ;;
  *)   install_one "$skill" ;;
esac

echo ""
echo "Next: set your key (the skill never handles the value) and prompt your agent."
echo "  export ENPROMPTA_API_KEY=ep_...        # dashboard -> API Keys"
echo "  then ask: \"Set up Enprompta tracing in my app.\""
