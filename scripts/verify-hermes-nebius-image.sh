#!/usr/bin/env bash
set -euo pipefail

TENKI_BIN="${TENKI_BIN:-$HOME/.local/bin/tenki}"
IMAGE_REF="${1:?Usage: $0 <private-image-digest> [sandbox-name]}"
NAME="${2:-hermes-nebius-verify-$(date +%Y%m%d-%H%M%S)}"
created=false

cleanup() {
  if "$created"; then
    "$TENKI_BIN" sandbox terminate --session "$NAME" --json >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

"$TENKI_BIN" sandbox create \
  --image "$IMAGE_REF" \
  --name "$NAME" \
  --cpu 2 \
  --memory-mb 4096 \
  --disk-size-gb 20 \
  --allow-inbound=false \
  --allow-outbound=false \
  --idle-timeout 2m \
  --max-duration 5m \
  --metadata purpose=hermes-nebius-image-verification \
  --metadata lifecycle=disposable \
  --json >/dev/null
created=true

"$TENKI_BIN" sandbox exec --session "$NAME" --timeout 60s -- bash -lc '
  set -euo pipefail
  export HOME=/home/tenki HERMES_HOME=/home/tenki/.hermes PI_CODING_AGENT_DIR=/home/tenki/.pi/agent PI_OFFLINE=1 PATH=/home/tenki/.local/bin:/usr/local/bin:$PATH
  hermes --version
  pi --version
  test -s /home/tenki/.hermes/config.yaml
  test -s /home/tenki/.pi/agent/models.json
  hermes config get model.provider | grep -qx nebius-token-factory
  hermes config get model.default | grep -qx nvidia/Nemotron-3-Ultra-550b-a55b
  for model in nvidia/Nemotron-3-Ultra-550b-a55b MiniMaxAI/MiniMax-M3 moonshotai/Kimi-K2.7-Code openai/gpt-oss-120b; do
    grep -q "$model" /home/tenki/.pi/agent/models.json
  done
  pi --list-models | grep -q moonshotai/Kimi-K2.7-Code
  pi --list-models | grep -q openai/gpt-oss-120b
  budget-estimate --profile developer-budget --input-tokens 1000000 --output-tokens 1000000 | grep -q "estimated_usd=\$0.7500"
  ! hermes-workshop --profile budget --query test >/dev/null 2>&1
  ! pi-subagent --profile budget --prompt test >/dev/null 2>&1
  echo hermes_nebius_image_no_key_verification=passed
'

echo "Verification passed. The disposable sandbox $NAME will now be terminated."
