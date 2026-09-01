#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent-tenki-workshop}"
PROJECT_DIR="${PI_WORKSHOP_PROJECT_DIR:-$HOME/workspaces/tenki-pi-workshop/landing-$(date +%Y%m%d-%H%M%S)}"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: start-landing-workshop.sh [--config-dir PATH] [--project-dir PATH] [--dry-run]

Starts an interactive Pi Coding Agent session with the five-question landing
page skill in a dedicated project directory. Run configure-local-pi-nebius.sh
first. Set NEBIUS_API_KEY in the current shell before a live session. No Render
deployment is triggered. This isolates project files, not the agent process.
EOF
}

while (($#)); do
  case "$1" in
    --config-dir) CONFIG_DIR="${2:?missing config directory}"; shift 2 ;;
    --project-dir) PROJECT_DIR="${2:?missing project directory}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

SKILL="$CONFIG_DIR/workshop-skills/landing-page-from-five-questions/SKILL.md"
PROMPT="$ROOT/prompts/landing-page-workshop.md"

if "$DRY_RUN"; then
  cat <<EOF
mode: dry-run
config_dir: $CONFIG_DIR
project_dir: $PROJECT_DIR
skill: $SKILL
Astro is installed locally per generated project
Render CLI is available but no deployment is triggered
EOF
  exit 0
fi

command -v pi >/dev/null || { printf 'Pi Coding Agent is not installed.\n' >&2; exit 1; }
test -s "$CONFIG_DIR/models.json" && test -s "$CONFIG_DIR/settings.json" && test -f "$SKILL" || {
  printf 'Workshop Pi configuration is incomplete. Run configure-local-pi-nebius.sh first.\n' >&2
  exit 1
}
[[ -n "${NEBIUS_API_KEY:-}" ]] || { printf 'NEBIUS_API_KEY is not set in this shell.\n' >&2; exit 2; }
[[ "$PROJECT_DIR" == "$HOME/"* ]] || { printf 'Project directory must be beneath HOME: %s\n' "$PROJECT_DIR" >&2; exit 2; }
if [[ -e "$PROJECT_DIR" ]] && [[ -n "$(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  printf 'Project directory is not empty: %s\n' "$PROJECT_DIR" >&2
  exit 2
fi
mkdir -p -m 700 "$PROJECT_DIR"
cd "$PROJECT_DIR"

PI_CODING_AGENT_DIR="$CONFIG_DIR" pi \
  --provider nebius-token-factory \
  --model MiniMaxAI/MiniMax-M3 \
  --no-context-files \
  --no-extensions \
  --no-skills \
  --no-prompt-templates \
  --tools read,bash,write \
  --skill "$SKILL" \
  "$(cat "$PROMPT")"
