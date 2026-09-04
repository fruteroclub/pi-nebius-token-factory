# Hermes Telegram control validation — 2026-09-04

## Image

```text
mlxs8y/hermes-nebius-workshop@sha256:e527cba4aa6e156cffc43d153b782fc473a420f2fde67d1a58bffe853f2735bd
```

Built from private technical branch `feat/hermes-nebius-tenki-image`, commit `1085c67`.

## Delivered control surface

The image includes a private in-sandbox controller:

```text
workshop-agent start
workshop-agent status
workshop-agent logs
workshop-agent stop
```

`start` launches Hermes’s Telegram long-polling gateway as a detached process. It requires all of these **only in the current managed SSH shell**:

- `NEBIUS_API_KEY`;
- `TELEGRAM_BOT_TOKEN`;
- `TELEGRAM_ALLOWED_USERS` containing numeric Telegram user IDs.

The launcher rejects a missing or malformed allowlist and refuses `GATEWAY_ALLOW_ALL_USERS=true`. It does not write either credential to disk, Git, image configuration, Tenki session configuration, or the public Builder Pack. Inbound networking remains disabled; Telegram long polling and Nebius inference require outbound networking.

The gateway uses the Hermes Budget model by default. An allowed operator can opt into the configured Pro alias for a chat session only via Telegram `/model hermes-pro`; `/new` returns to the Budget default.

## Verification

### Local source/lifecycle checks

```text
workshop-agent start with a fake gateway → PASS
workshop-agent status → PASS
workshop-agent stop (SIGTERM) → PASS
post-stop status → PASS
bash tests/hermes-nebius.test.sh → PASS
bash tests/workshop-harness.test.sh → PASS
bash -n scripts/verify-hermes-nebius-image.sh → PASS
git diff --check → PASS
```

### Disposable private-image check

A temporary sandbox was created with both inbound and outbound networking disabled, then terminated automatically.

```text
Hermes Agent 0.21.0 → PASS
Pi Coding Agent 0.84.4 → PASS
Nebius provider and Budget default → PASS
all four configured model definitions → PASS
workshop-agent installed → PASS
workshop-agent start without runtime credentials → correctly rejected
verification sandbox teardown → PASS ([] active)
```

## Remaining live gate

No Telegram bot token or Nebius key was used in this validation. Therefore the following remain unproven:

1. BotFather credential acceptance and Telegram long-poll connection;
2. numeric Telegram allowlist behavior for the designated operator;
3. an authenticated Hermes Budget reply through Nebius;
4. provider-reported token usage/cost monitoring and the $25 operating boundary;
5. Hermes-to-Pi developer delegation from a Telegram session.

Run that final check only in a short outbound-enabled, inbound-disabled sandbox while the operator enters both credentials personally through managed SSH. Terminate the sandbox when the check is complete.
