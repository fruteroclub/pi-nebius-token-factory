#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 -m json.tool "$ROOT/.tenki/hermes-nebius-template.json" >/dev/null
python3 -m json.tool "$ROOT/hermes-nebius/config/pi-models.json" >/dev/null
python3 -m json.tool "$ROOT/hermes-nebius/config/pi-settings.json" >/dev/null
bash -n "$ROOT/hermes-nebius/bin/hermes-workshop"
bash -n "$ROOT/hermes-nebius/bin/pi-subagent"
python3 -m py_compile "$ROOT/hermes-nebius/bin/budget-estimate"

grep -q '"apiKey": "${NEBIUS_API_KEY}"' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'nvidia/Nemotron-3-Ultra-550b-a55b' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'MiniMaxAI/MiniMax-M3' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'moonshotai/Kimi-K2.7-Code' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q 'openai/gpt-oss-120b' "$ROOT/hermes-nebius/config/pi-models.json"
grep -q '"moonshotai/Kimi-K2.7-Code"' "$ROOT/hermes-nebius/config/pi-settings.json"
grep -q '"openai/gpt-oss-120b"' "$ROOT/hermes-nebius/config/pi-settings.json"
grep -q 'nebius-token-factory' "$ROOT/.tenki/hermes-nebius-template.json"
! grep -REn --exclude='hermes-nebius.test.sh' --exclude='README.md' '(NEBIUS_API_KEY=.+[^}]|--api-key)' "$ROOT/hermes-nebius" >/dev/null

python3 "$ROOT/hermes-nebius/bin/budget-estimate" --profile hermes-budget --input-tokens 1000000 --output-tokens 1000000 | grep -q 'estimated_usd=\$1.3000'
echo 'Hermes + Pi Nebius image source checks passed'
