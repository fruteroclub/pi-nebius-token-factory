#!/usr/bin/env bash
set -euo pipefail

TENKI_BIN="${TENKI_BIN:-$HOME/.local/bin/tenki}"
IMAGE_REF="${1:?Usage: $0 <private-image-digest> [sandbox-name]}"
NAME="${2:-bt-pi-$(date +%Y%m%d-%H%M%S)}"

[[ -x "$TENKI_BIN" ]] || { printf 'Tenki CLI not found: %s\n' "$TENKI_BIN" >&2; exit 1; }

"$TENKI_BIN" sandbox create \
  --image "$IMAGE_REF" \
  --name "$NAME" \
  --allow-inbound=false \
  --allow-outbound=true \
  --idle-timeout 15m \
  --max-duration 2h \
  --metadata purpose=pi-nebius-workshop \
  --metadata lifecycle=disposable

printf '\nTerminate after the demo unless explicitly keeping it live:\n%s sandbox terminate --session %s\n' "$TENKI_BIN" "$NAME"
