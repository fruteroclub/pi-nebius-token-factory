#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$ROOT/.test-pi-config"
trap 'rm -rf "$CONFIG_DIR"' EXIT

config_output="$(HOME="$ROOT/.test-home" bash "$ROOT/scripts/configure-local-pi-nebius.sh" --config-dir "$CONFIG_DIR" --dry-run)"
grep -q "config_dir: $CONFIG_DIR" <<<"$config_output"
grep -q 'no files were written' <<<"$config_output"
test ! -e "$CONFIG_DIR/models.json"

HOME="$ROOT/.test-home" bash "$ROOT/scripts/configure-local-pi-nebius.sh" --config-dir "$CONFIG_DIR"
test -s "$CONFIG_DIR/models.json"
test -s "$CONFIG_DIR/settings.json"
test -f "$CONFIG_DIR/workshop-skills/landing-page-from-five-questions/SKILL.md"
grep -q '"apiKey": "\$NEBIUS_API_KEY"' "$CONFIG_DIR/models.json"

launch_output="$(HOME="$ROOT/.test-home" bash "$ROOT/scripts/start-landing-workshop.sh" --config-dir "$CONFIG_DIR" --project-dir "$ROOT/.test-project" --dry-run)"
grep -q 'mode: dry-run' <<<"$launch_output"
grep -q "project_dir: $ROOT/.test-project" <<<"$launch_output"
grep -q 'Astro is installed locally per generated project' <<<"$launch_output"
grep -q 'Render CLI is available but no deployment is triggered' <<<"$launch_output"
grep -q -- '--no-context-files' "$ROOT/scripts/start-landing-workshop.sh"
grep -q -- '--no-extensions' "$ROOT/scripts/start-landing-workshop.sh"
grep -q -- '--no-skills' "$ROOT/scripts/start-landing-workshop.sh"

test_launch_output="$(bash "$ROOT/scripts/launch-tenki-image-test.sh" 'workspace/image@sha256:test' pi-nebius-test --dry-run)"
grep -q 'mode: dry-run' <<<"$test_launch_output"
grep -q 'max_duration: 10m' <<<"$test_launch_output"
grep -q 'allow_inbound: false' <<<"$test_launch_output"
grep -q 'terminate_after_verification: true' <<<"$test_launch_output"

grep -q 'npm prefix -g)/bin/pi' "$ROOT/.tenki/template.json"
grep -q '/usr/sbin/sshd -D -e' "$ROOT/.tenki/template.json"
grep -q 'openssh-server' "$ROOT/.tenki/template.json"
grep -q '"runAt": "boot"' "$ROOT/.tenki/template.json"

echo 'workshop harness tests passed'
