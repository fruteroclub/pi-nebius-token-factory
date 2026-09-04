# Hermes + Pi Nebius Token Factory Tenki image

A private, disposable Tenki image for a two-agent workshop environment:

- **Hermes Agent** is the orchestrator and main agent.
- **Pi Coding Agent** is a bounded developer subagent that Hermes can invoke through `pi-subagent`.
- **Nebius Token Factory** is the sole inference provider.

No API key is built into the image.

## Model matrix

| Role | Profile | Model | Context | Token price (input / output per 1M) |
|---|---|---|---:|---:|
| Hermes | Pro | `nvidia/Nemotron-3-Ultra-550b-a55b` | 1M | $1.00 / $3.00 |
| Hermes | Budget | `MiniMaxAI/MiniMax-M3` | 1M | $0.30 / $1.00 |
| Pi | Pro | `moonshotai/Kimi-K2.7-Code` | 262K | $0.95 / $4.00 |
| Pi | Budget | `openai/gpt-oss-120b` | 131K | $0.15 / $0.60 |

Use Budget by default. Escalate only the agent whose task warrants it.

## Budget boundary

The workshop ceiling is **$25 USD total**. The image includes `budget-estimate` for estimating individual responses from provider-reported token usage.

The image cannot itself enforce an account-level billing ceiling: serverless inference is billed by Nebius Token Factory outside the sandbox. Before the workshop, set a $25 project/account spending limit in Token Factory **if its account controls expose one**; otherwise the facilitator must monitor the billing dashboard and stop sessions at the ceiling. Do not call this a hard cap until that provider control is verified.

Suggested operating envelope:

```text
$12  Hermes usage
$8   Pi subagent usage
$5   incident reserve
```

## Launch

Create the session with outbound networking enabled and inbound disabled. Once connected through managed SSH, enter the key into that shell only:

```bash
export NEBIUS_API_KEY='[REDACTED]'
hermes-workshop --profile budget
```

The key is not persisted. Start a Hermes Pro session with `--profile pro`.

To request a developer pass from Hermes, use its installed `pi-developer-subagent` skill. The underlying direct command is:

```bash
pi-subagent --profile budget --workdir /home/tenki/workspace/example --prompt 'Inspect the project and return a test-first implementation plan. Do not edit files.'
```

Use `budget-estimate --profile developer-budget --input-tokens 10000 --output-tokens 2000` to estimate a call from reported usage.

## Telegram operator control

`workshop-agent` provides a private Telegram control plane inside a running Tenki sandbox:

```text
workshop-agent start
workshop-agent status
workshop-agent logs
workshop-agent stop
```

It runs Hermes through Telegram **long polling**: outbound networking must be enabled, inbound networking remains disabled, and no public port or webhook is used. The gateway only starts when all three values are present in the current managed SSH shell:

- `NEBIUS_API_KEY` — Nebius Token Factory credential;
- `TELEGRAM_BOT_TOKEN` — BotFather credential for a dedicated private bot;
- `TELEGRAM_ALLOWED_USERS` — one or more comma-separated numeric Telegram user IDs.

The command rejects a missing/invalid allowlist and refuses `GATEWAY_ALLOW_ALL_USERS=true`. It does not write either credential to disk, Git, the image, or Tenki session configuration. Hermes secret redaction remains enabled.

### First use

1. Create a dedicated bot through [@BotFather](https://t.me/BotFather). Keep its token private.
2. Obtain your numeric Telegram ID (for example, by messaging [@userinfobot](https://t.me/userinfobot)). Do not use a Telegram username as the allowlist value.
3. Create a Tenki sandbox from this image with **outbound enabled** and **inbound disabled**, then connect via managed SSH.
4. In that SSH shell, enter credentials without echoing them or adding them to shell history:

```bash
read -rsp 'Nebius Token Factory key: ' NEBIUS_API_KEY; echo; export NEBIUS_API_KEY
read -rsp 'Telegram bot token: ' TELEGRAM_BOT_TOKEN; echo; export TELEGRAM_BOT_TOKEN
export TELEGRAM_ALLOWED_USERS='<your-numeric-Telegram-ID>'
workshop-agent start
```

Open the bot’s direct message in Telegram and send `/whoami`; it should report the allowed account. `/status` shows the current Hermes session, `/stop` cancels a running agent turn, and `/model hermes-pro` temporarily escalates that Telegram session. `/new` returns it to the Budget default.

### Stop and cleanup

```bash
workshop-agent stop
```

This stops the Telegram gateway and ends the process that holds the runtime-only credentials. Then terminate the Tenki sandbox from the operator terminal when the session is over; stopping the gateway alone does not terminate the sandbox.

Do not add the bot to a group or turn off BotFather privacy mode for this private operator workflow. A Telegram bot token grants control of the bot: revoke it in BotFather immediately if it is exposed.

## Build and no-key verification

```bash
tenki template build hermes-nebius-workshop --file .tenki/hermes-nebius-template.json
```

Verify only the installed binaries, model configuration, aliases, and launchers before entering any key. Terminate every test sandbox immediately after the check.
