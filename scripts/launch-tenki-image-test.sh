#!/usr/bin/env bash
set -euo pipefail

TENKI_BIN="${TENKI_BIN:-$HOME/.local/bin/tenki}"
IMAGE_REF="${1:?Usage: $0 <private-image-digest> [sandbox-name] [--dry-run]}"
NAME="${2:-pi-nebius-test-$(date +%Y%m%d-%H%M%S)}"
DRY_RUN=false

if [[ "${3:-}" == "--dry-run" ]] || [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  [[ "${2:-}" == "--dry-run" ]] && NAME="pi-nebius-test-dry-run"
fi

[[ -x "$TENKI_BIN" ]] || { printf 'Tenki CLI not found: %s\n' "$TENKI_BIN" >&2; exit 1; }

if "$DRY_RUN"; then
  cat <<EOF
mode: dry-run
image: $IMAGE_REF
name: $NAME
allow_inbound: false
allow_outbound: true
max_duration: 10m
idle_timeout: 5m
terminate_after_verification: true
EOF
  exit 0
fi

created=false
cleanup() {
  if "$created"; then
    "$TENKI_BIN" sandbox terminate --session "$NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup ERR

"$TENKI_BIN" sandbox create \
  --image "$IMAGE_REF" \
  --name "$NAME" \
  --allow-inbound=false \
  --allow-outbound=true \
  --idle-timeout 5m \
  --max-duration 10m \
  --metadata purpose=pi-nebius-image-verification \
  --metadata lifecycle=disposable >/dev/null
created=true
trap - ERR

cat <<EOF
READY
sandbox: $NAME
verify: $TENKI_BIN sandbox exec --session $NAME --timeout 30s -- bash -lc 'pi --version && render --version && test -s /home/tenki/.pi/agent/models.json && test -s /home/tenki/.pi/agent/settings.json'
connect_for_user_key: $TENKI_BIN sandbox ssh --session $NAME
terminate: $TENKI_BIN sandbox terminate --session $NAME
EOF
