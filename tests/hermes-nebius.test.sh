#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 -m json.tool "$ROOT/.tenki/hermes-nebius-template.json" >/dev/null
python3 -m json.tool "$ROOT/hermes-nebius/config/pi-models.json" >/dev/null
python3 -m json.tool "$ROOT/hermes-nebius/config/pi-settings.json" >/dev/null
bash -n "$ROOT/hermes-nebius/bin/hermes-workshop"
bash -n "$ROOT/hermes-nebius/bin/pi-subagent"
bash -n "$ROOT/hermes-nebius/bin/workshop-agent"
# Canonical VM bootstrapper lives in the public Builder Pack and is installed at image build time.
grep -q 'f2960df12bf1641d1555e455f96831ef38802ccc' "$ROOT/.tenki/hermes-nebius-template.json"
grep -q 'onboard-telegram-agent /home/tenki/.local/bin/onboard-telegram-agent' "$ROOT/.tenki/hermes-nebius-template.json"
python3 -m py_compile "$ROOT/hermes-nebius/bin/budget-estimate"

test -x "$ROOT/hermes-nebius/bin/workshop-agent"
! "$ROOT/hermes-nebius/bin/workshop-agent" start >/dev/null 2>&1

grep -q '"apiKey": "${NEBIUS_API_KEY}"' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'nvidia/Nemotron-3-Ultra-550b-a55b' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'MiniMaxAI/MiniMax-M3' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'moonshotai/Kimi-K2.7-Code' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'openai/gpt-oss-120b' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q '"moonshotai/Kimi-K2.7-Code"' "$ROOT/hermes-nebius/config/pi-settings.json"
grep -q '"openai/gpt-oss-120b"' "$ROOT/hermes-nebius/config/pi-settings.json"
grep -q 'nebius-token-factory' "$ROOT/.tenki/hermes-nebius-template.json"
grep -q 'model.default MiniMaxAI/MiniMax-M3' "$ROOT/.tenki/hermes-nebius-template.json"
grep -q 'hermes-nebius/bin/workshop-agent /home/tenki/.local/bin/workshop-agent' "$ROOT/.tenki/hermes-nebius-template.json"
grep -q 'hermes config get model.default | grep -qx MiniMaxAI/MiniMax-M3' "$ROOT/scripts/verify-hermes-nebius-image.sh"
grep -q '! workshop-agent start' "$ROOT/scripts/verify-hermes-nebius-image.sh"
grep -q 'onboard-telegram-agent --help' "$ROOT/scripts/verify-hermes-nebius-image.sh"
grep -q '! onboard-telegram-agent' "$ROOT/scripts/verify-hermes-nebius-image.sh"
! grep -REn --exclude='hermes-nebius.test.sh' --exclude='README.md' '(NEBIUS_API_KEY=.+[^}]|TELEGRAM_BOT_TOKEN=.+[^}]|--api-key)' "$ROOT/hermes-nebius" >/dev/null

python3 "$ROOT/hermes-nebius/bin/budget-estimate" --profile hermes-budget --input-tokens 1000000 --output-tokens 1000000 | grep -q 'estimated_usd=\$1.3000'
echo 'Hermes + Pi Nebius image source checks passed'
