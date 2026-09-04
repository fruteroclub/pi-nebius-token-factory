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

## Build and no-key verification

```bash
tenki template build hermes-nebius-workshop --file .tenki/hermes-nebius-template.json
```

Verify only the installed binaries, model configuration, aliases, and launchers before entering any key. Terminate every test sandbox immediately after the check.
