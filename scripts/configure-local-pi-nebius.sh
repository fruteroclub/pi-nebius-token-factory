#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent-tenki-workshop}"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: configure-local-pi-nebius.sh [--config-dir PATH] [--dry-run]

Creates an isolated Pi Coding Agent configuration for the workshop. It copies
only provider settings, models, and the workshop skill. It never overwrites
~/.pi/agent and never writes a Nebius API key.
EOF
}

while (($#)); do
  case "$1" in
    --config-dir) CONFIG_DIR="${2:?missing config directory}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if "$DRY_RUN"; then
  printf 'mode: dry-run\nconfig_dir: %s\nno files were written\n' "$CONFIG_DIR"
  exit 0
fi

install -d -m 700 "$CONFIG_DIR" "$CONFIG_DIR/workshop-skills"
install -m 600 "$ROOT/models.json" "$CONFIG_DIR/models.json"
install -m 600 "$ROOT/settings.json" "$CONFIG_DIR/settings.json"
cp -R "$ROOT/skills/landing-page-from-five-questions" "$CONFIG_DIR/workshop-skills/"
chmod 700 "$CONFIG_DIR/workshop-skills/landing-page-from-five-questions"
chmod 600 "$CONFIG_DIR/workshop-skills/landing-page-from-five-questions/SKILL.md"
printf 'Configured isolated Pi directory: %s\n' "$CONFIG_DIR"
