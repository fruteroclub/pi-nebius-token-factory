# Pi Coding Agent on Nebius Token Factory

A clean, reproducible setup for running [Pi Coding Agent](https://pi.dev) against [Nebius Token Factory](https://tokenfactory.nebius.com) open-weight models — with **per-token cost tracking that reports real dollars**, not zeros.

Pi already tracks token usage and cost natively. No extension, no proxy, no wrapper. But three configuration defaults will silently give you wrong numbers — or no output at all — and every secondary source we checked had at least one model's specs wrong. This guide is the version that survives contact with those problems.

**Status:** steps 1–5 complete and verified. All seven models smoke-tested.

---

## Why this exists

If you want to know what an agentic coding task actually costs, you need four things to be true at once:

1. The agent reports token usage per message. *Pi does, natively.*
2. The per-model prices are correct. *They default to zero — see step 4.*
3. The context window is correct. *It defaults to 128000 — see step 4.*
4. The output cap is high enough. *It defaults to 16384 — see step 4.*

Miss #2 and every task reports **$0.00**. Miss #3 and a 1M-context model is silently clamped to 128K. Miss #4 and long outputs are truncated mid-file and never written. **None of the three raises an error.**

---

## Prerequisites

- Node.js and npm
- A Nebius Token Factory API key — [create one here](https://tokenfactory.nebius.com/?modals=create-api-key)
- macOS or Linux. Shell examples are zsh; adapt paths for bash

---

## Step 1 — Install Pi

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

`--ignore-scripts` disables dependency lifecycle scripts during install. Pi does not require install scripts for normal npm installs, so this is free hardening. Source: [pi.dev/docs/latest](https://pi.dev/docs/latest).

Verify:

```bash
pi --version
which pi
```

Verified against **0.82.1**. Note where the binary lands — with `nvm`, it goes into the *active* Node version's prefix. Installing under one Node version and running under another is a common way to get `command not found`.

---

## Step 2 — Set your API key

Put it in `~/.zshenv`, **not** `~/.zshrc`:

```bash
export NEBIUS_API_KEY="<your-key>"
```

zsh reads `~/.zshenv` for *every* shell, interactive or not. `.zshrc` is only read by interactive shells, so anything non-interactive — scripts, daemons, tooling that spawns its own shell — would not see the key.

### ⚠️ Do not append with `echo >>`

Two hazards, both real:

**Shell history.** `echo 'export NEBIUS_API_KEY="..."' >> ~/.zshenv` writes your key into `~/.zsh_history` in plaintext.

**Missing trailing newline.** If the file does not already end in a newline, `>>` concatenates onto the last line. You get this:

```
export SOME_OTHER_TOKEN=abc123export NEBIUS_API_KEY="..."
```

Now `SOME_OTHER_TOKEN`'s value silently swallows the entire export statement, and `NEBIUS_API_KEY` is never defined. Two broken variables, no error message.

Use `read` with an explicit newline in the `printf` format instead — the key never enters a command, so it never enters your history:

```bash
read -rs "k?Nebius key: "
printf 'export NEBIUS_API_KEY="%s"\n' "$k" >> ~/.zshenv
unset k
```

The `\n` in the format string is the fix: it always terminates the line, so the next append cannot collide.

Open a new terminal and verify **without printing the key**:

```bash
echo ${#NEBIUS_API_KEY}
```

`0` means not set. Any other number is the character count.

---

## Step 3 — Fetch the live model catalog

```bash
curl -s "https://api.tokenfactory.nebius.com/v1/models?verbose=true" \
  -H "Authorization: Bearer $NEBIUS_API_KEY" > nebius-models.json
```

```bash
jq -r '.data | sort_by(.id)[] | [.id, .context_length,
  ((.pricing.prompt|tonumber)*1000000), ((.pricing.completion|tonumber)*1000000),
  ((.supported_features//[])|join(","))] | @tsv' nebius-models.json | column -t -s$'\t'
```

Each entry carries `id`, `context_length`, `pricing` (per-token decimal strings), `architecture.modality`, `supported_features`, `regions`, and `per_request_limits`.

### This endpoint is the only source of truth

We cross-checked the catalog against the Nebius marketing page, Artificial Analysis, and a community relay's bundled model table. **Each one disagreed with the API on at least one model.** Checked 2026-07-29:

| Claim | Source | API says | Verdict |
|---|---|---|---|
| Kimi K3 context = 262K | community relay table | 1,048,576 | API right |
| Nemotron-3-Ultra context = 262K | Artificial Analysis | 1,048,576 | API right |
| MiniMax-M3 context = 1M | Nebius page + AA | 8000 | **API wrong** — see below |
| Kimi-K2.7-Code context = 256K | relay table + AA | 8000 | **API wrong** — see below |

Prices, by contrast, matched the marketing page exactly.

### `context_length: 8000` on the newest models is placeholder metadata

Two models — `MiniMaxAI/MiniMax-M3` and `moonshotai/Kimi-K2.7-Code` — report `context_length: 8000`, against 1M and 256K on Artificial Analysis. Both are recent additions.

**We tested it rather than guessing.** A 45,700-token prompt sent to each, asking a question only answerable by reading the whole input:

```bash
# ~2,600 numbered filler lines + "How many items are listed above?"
curl -s "https://api.tokenfactory.nebius.com/v1/chat/completions" \
  -H "Authorization: Bearer $NEBIUS_API_KEY" -H "Content-Type: application/json" \
  --data-binary @big-prompt.json
```

| Model | Result |
|---|---|
| `MiniMaxAI/MiniMax-M3` | HTTP 200, `prompt_tokens: 45714`, answered `2600` — correct |
| `moonshotai/Kimi-K2.7-Code` | HTTP 200, `prompt_tokens: 45535`, answered `2600` — correct |

So `8000` is wrong and Artificial Analysis is right. **Do not disqualify a model on this field alone** — send an oversized prompt and see whether it is actually rejected. Conversely, don't take the published 1M on faith either: ~45K is what we verified, so this repo's config sets a conservative `contextWindow` rather than the advertised ceiling.

### ⚠️ Reasoning tokens can consume your entire `max_tokens`

The first run of that test used `max_tokens: 24` and returned **HTTP 200 with an empty `content` string** — no error, nothing to catch. Both models had spent the whole budget on `reasoning` before emitting any answer. Raising `max_tokens` to 600 produced the correct reply immediately.

If a reasoning-capable model returns empty content on a successful call, the budget is the first thing to check, not the prompt.

So the rule is narrower than "trust the API": **the API is authoritative for model IDs and prices, and a starting point for context windows.** Where a context figure looks implausible, test it. And re-check any figure before publishing — the catalog moves.

### Absent ≠ removed

`/v1/models` lists what is **currently servable**. A model pulled for maintenance disappears from it exactly the same way a permanently delisted model does, and nothing in the response distinguishes the two.

We hit this with `zai-org/GLM-5.2`. It vanished from the catalog on 2026-07-27, and a community relay's documentation stated flatly that Nebius had "removed" it. It was easy — and wrong — to conclude it was discontinued.

**It came back.** On 2026-07-30 the catalog returned 26 models with `zai-org/GLM-5.2` among them, serving normally. It had been downtime the whole time. Had we treated the absence as permanent, we would have dropped the **#2 open-weight model on Artificial Analysis** from our roster over a maintenance window.

Check [status.nebius.com](https://status.nebius.com) before assuming a missing model is gone for good.

*(Note the domain: `status.nebius.com`, not `status.nebius.ai` — the latter does not resolve.)*

Practical consequence for a benchmark: pin the model IDs you intend to use, and if one goes missing mid-run, find out **why** before substituting. A model that is merely down will come back, and swapping it out permanently changes what you are measuring.

> The `8000` values on MiniMax-M3 and Kimi-K2.7-Code have been **disproven** — see the test above. Both handle 45K+ correctly. Keep the general lesson: a surprising metadata value is a prompt to test, not a reason to disqualify.

---

## Step 4 — Configure `models.json`

Pi reads custom providers from `~/.pi/agent/models.json`. Reference: [pi.dev/docs/latest/models](https://pi.dev/docs/latest/models).

A working config with all seven roster models is in this repo: **[`models.json`](models.json)**. Install it:

```bash
mkdir -p ~/.pi/agent
cp models.json ~/.pi/agent/models.json
chmod 600 ~/.pi/agent/models.json
```

`"$NEBIUS_API_KEY"` is environment interpolation — Pi resolves it at request time, so the key never lives in the config file.

**The three defaults that will silently corrupt your data:**

| Field | Default | If you omit it |
|---|---|---|
| `cost` | all zeros | Pi reports **$0.00** for every task. Tokens still count; dollars do not |
| `contextWindow` | `128000` | A 1M-context model is clamped to 128K |
| `maxTokens` | `16384` | Long outputs are **truncated mid-file**. No error, exit code 0 |

All three are **per-model fields in `models.json`**. There is no global setting and no CLI flag — Pi's `settings.json` holds only `defaultProvider`, `defaultModel`, `defaultThinkingLevel`, `enabledModels`, and three UI modes. Every model you add later starts from these defaults again.

### ⚠️ `maxTokens` — the one that cost us a run

We lost a full agentic run to this. Two phases asked the model to write source files, both exceeded 16,384 output tokens, both were cut off mid-file, and **nothing reached disk**. The session log showed `stopReason: "length"`; the shell showed exit code 0, empty stdout, empty stderr. Roughly half an hour of wall-clock produced no artifacts and no error.

If an agentic phase produces nothing, check the stop reason before you check anything else:

```bash
grep -o '"stopReason":"[a-z]*"' ~/.pi/agent/sessions/*/*.jsonl | sort | uniq -c
```

`length` means truncation, not refusal.

**Nebius does not publish a per-model output ceiling.** The only limit field on `/v1/models` is `per_request_limits`, and that is rate limiting — `tokens_per_minute`, `requests_per_minute`, `burst_ratio` — not a cap on a single response.

The one published per-model ceiling that *is* real is `context_length`, and a response can never exceed the context window. So set `maxTokens` to the model's context length and the cap stops being a binding constraint:

```json
{ "id": "moonshotai/Kimi-K3", "contextWindow": 1048576, "maxTokens": 1048576 }
```

Verified empirically: Nebius accepted `max_tokens: 262144` on Kimi K3 without complaint, so the API is not the limit — Pi's default was.

**The trade-off is a runaway turn.** `maxTokens` is a ceiling, not a reservation — you are billed only on tokens generated — but it does bound the worst case. At Kimi K3's $15/1M output, a single turn that ran to 1,048,576 tokens would cost about **$15.73**. Most models in this catalog are far cheaper: GLM-5.2 tops out near $0.87, gpt-oss-120b near $0.08. Pick the ceiling you are willing to pay for once.

`cost` is expressed in **per-million-token rates** — the API returns per-token decimals, so multiply by 1,000,000.

### ⚠️ You need `compat` or every request fails with 422

This one is not optional. Without it:

```
422 status code (no body)
```

The same request via plain `curl` returns `200`, which is what makes this confusing — the API is fine, Pi is sending something Nebius rejects. Pi uses the OpenAI `developer` role for reasoning-capable models; Nebius does not accept it. Set that off at the **provider** level:

```json
"compat": {
  "supportsDeveloperRole": false
}
```

**Only this one flag is needed.** Pi's docs mention `supportsReasoningEffort` in the same breath, and it is tempting to set both — we did, and it was wrong. Isolated with a throwaway config dir:

| `supportsDeveloperRole` | `supportsReasoningEffort` | Result |
|---|---|---|
| `false` | `true` | ✅ works — `--thinking high` accepted, correct answer returned |
| `true` | `false` | ❌ fails |

Disabling `supportsReasoningEffort` costs you `--thinking` control for no benefit. Leave it on.

If you hit a bare 422 with no body, test the model with `curl` first — a `200` there tells you the problem is client-side, and then **change one flag at a time**. Setting two at once is how you end up with a working config that quietly does less than it should.

> Even with `reasoning_effort` enabled and `--thinking high`, GLM-5.1 reported `reasoning: 0` tokens. Nebius accepts the parameter without erroring; whether it acts on it is unconfirmed. `usage.reasoning` in the session log is how you check per model.

### Isolate config experiments safely

`PI_CODING_AGENT_DIR` points Pi at a different config directory, so you can test provider settings without touching your working setup:

```bash
PI_CODING_AGENT_DIR=/tmp/pi-test/agent pi --model "zai-org/GLM-5.1" -p "test"
```

### Verify

```bash
pi --list-models nebius-token-factory
```

```
provider              model                              context  max-out  thinking  images
nebius-token-factory  MiniMaxAI/MiniMax-M3              196.6K   16.4K    yes       no
nebius-token-factory  moonshotai/Kimi-K3                 1.0M     16.4K    yes       yes
nebius-token-factory  NousResearch/Hermes-4-70B          131.1K   16.4K    yes       no
nebius-token-factory  nvidia/Nemotron-3-Ultra-550b-a55b  1.0M     16.4K    yes       no
nebius-token-factory  openai/gpt-oss-120b                131.1K   16.4K    yes       no
nebius-token-factory  Qwen/Qwen3.5-397B-A17B             262.1K   16.4K    yes       no
nebius-token-factory  zai-org/GLM-5.1                    202.8K   16.4K    yes       no
```

`1.0M` on Kimi-K3 and Nemotron-Ultra confirms the `contextWindow` override took — without it both would read `128.0K`.

Then a live call on the cheapest model:

```bash
pi --provider nebius-token-factory --model "NousResearch/Hermes-4-70B" -p "Reply with exactly: OK"
```

### Confirm cost is real

The whole point. Read the newest session file:

```bash
f=$(find ~/.pi/agent/sessions -name "*.jsonl" -exec stat -f '%m %N' {} \; | sort -rn | head -1 | cut -d' ' -f2-)
grep -o '"usage":{[^}]*}[^}]*}' "$f" | tail -1
```

An actual result from the smoke test above:

```json
{
  "input": 6125, "output": 2, "cacheRead": 0, "cacheWrite": 0,
  "reasoning": 0, "totalTokens": 6127,
  "cost": { "input": 0.00079625, "output": 0.0000008, "total": 0.00079705 }
}
```

**A non-zero `cost.total` means the setup is complete.** If it reads `0`, your `cost` fields did not load.

> Note: `cacheRead` reports `0` here, but a direct `curl` to the same model returned `"cached_tokens": 16` — so Nebius does cache prompts. Nebius publishes no cache pricing, so this config sets `cacheRead`/`cacheWrite` to `0`. Cached input may therefore be slightly over-counted at full rate. Unresolved.

---

## Step 5 — Set defaults so bare `pi` works

Without `~/.pi/agent/settings.json` you must pass `--provider` and `--model` on every invocation. A working file is in this repo: **[`settings.json`](settings.json)**.

```bash
cp settings.json ~/.pi/agent/settings.json
```

```json
{
  "defaultProvider": "nebius-token-factory",
  "defaultModel": "MiniMaxAI/MiniMax-M3",
  "defaultThinkingLevel": "off",
  "enabledModels": ["nebius-token-factory/MiniMaxAI/MiniMax-M3", "..."]
}
```

`enabledModels` controls which models cycle on Ctrl+P. Entries are `provider/model-id`.

Verify:

```bash
pi -p "Reply with exactly: OK"
```

### Why MiniMax-M3 as the default

A 428B MoE reasoning model, and the value pick of the whole catalog: **Artificial Analysis 44** — only 13 behind Kimi K3 — at **$0.30 / $1.20** and 248 tok/s. It beats its own sibling `MiniMax-M2.5` on every axis (AA 44 vs 34, ~7× the throughput) for exactly the same price.

It was very nearly excluded: the API reports `context_length: 8000` for it. That turned out to be placeholder metadata (see step 3), and dropping it on that basis would have cost ten AA points for nothing.

When you want a still-higher ceiling, `nvidia/Nemotron-3-Ultra-550b-a55b` runs at **523 tok/s** with a higher score and a 1M context, at 3.3× the input price. Escalate with `--model`, don't default to it.

## Verified: all seven models

Every model in the roster was smoke-tested with the same trivial prompt (`"Reply with exactly: OK"`) on 2026-07-29. All seven responded.

| Model | AA | Cost of that one call | $/1M in | Tok/s |
|---|---|---|---|---|
| `moonshotai/Kimi-K3` | 57 | $0.0184 | 3.00 | 120 |
| `zai-org/GLM-5.1` | 40 | $0.0085 | 1.40 | 25 |
| `nvidia/Nemotron-3-Ultra-550b-a55b` | 38 | $0.0068 | 1.00 | 523 |
| `Qwen/Qwen3.5-397B-A17B` | 34 | $0.0040 | 0.60 | 80 |
| `MiniMaxAI/MiniMax-M3` | 44 | $0.0019 | 0.30 | 248 |
| `MiniMaxAI/MiniMax-M2.5` | 34 | $0.0019 | 0.30 | 37 |
| `openai/gpt-oss-120b` | 24 | $0.0009 | 0.15 | 40 |
| `NousResearch/Hermes-4-70B` | 10 | $0.0008 | 0.13 | 20 |

Total for all seven: **$0.041**.

### The number worth staring at

Each of those calls consumed **~6,000 input tokens** to answer *"Reply with exactly: OK"*. That is Pi's system prompt plus tool definitions, resent on every turn. Before you write a single line of your actual task, that is the floor.

It is also why input price dominates output price for agentic work, and why a model that is 5× cheaper on input beats one that is 5× cheaper on output.

## Model roster

One model per lab, best-of-lab by [Artificial Analysis](https://artificialanalysis.ai/models/open-source) Intelligence Index v4.1. IDs and context windows verbatim from the API, 2026-07-29.

| Lab | Model ID | AA | Context | $/1M in | $/1M out | Region |
|---|---|---|---|---|---|---|
| Moonshot AI | `moonshotai/Kimi-K3` | 57 | 1,048,576 | 3.00 | 15.00 | eu-west2 |
| Z.ai | `zai-org/GLM-5.1` | 40 | 202,752 | 1.40 | 4.40 | eu-north1 |
| NVIDIA | `nvidia/Nemotron-3-Ultra-550b-a55b` | 38 | 1,048,576 | 1.00 | 3.00 | us-central1 |
| Alibaba | `Qwen/Qwen3.5-397B-A17B` | 34 | 262,144 | 0.60 | 3.60 | us-central1 |
| MiniMax | `MiniMaxAI/MiniMax-M3` | **44** | see note | 0.30 | 1.20 | us-central1 |
| OpenAI | `openai/gpt-oss-120b` | 24 | 131,072 | 0.15 | 0.60 | eu-north1 |
| Nous Research | `NousResearch/Hermes-4-70B` | 10 | 131,072 | 0.13 | 0.40 | eu-north1 |

All seven report `tools` and `reasoning` support. `MiniMax-M3` and `MiniMax-M2.5` do not report `json_mode` / `structured_outputs`; the rest do.

**MiniMax-M3 context:** Artificial Analysis says 1M, the API says 8000, and we verified 45,714 by test. This repo's config sets `196608` — comfortably above what is proven, well below what is claimed. Raise it if you verify higher.

`gpt-oss-120b` is from OpenAI but open-weight, so it belongs in an open-model roster.

### Not usable as coding agents

These three report **no `tools` capability**, so they cannot drive an agent regardless of their benchmark scores:

- `Qwen/Qwen2.5-VL-72B-Instruct`
- `openbmb/MiniCPM-V-4_5`
- `nvidia/Llama-3_1-Nemotron-Ultra-253B-v1` — has `json_mode`, `structured_outputs` and `reasoning`, but no `tools`

### One counterintuitive result

**`Hermes-4-70B` outperforms `Hermes-4-405B`** on the AA index — 10 vs 9 — at $0.13/$0.40 against $1.00/$3.00. The 405B is roughly 8× the price for a lower score. Picking best-of-lab surfaces this; picking biggest-of-lab hides it.

---

## Where cost data lands

Pi writes one JSONL file per session under `~/.pi/agent/sessions/<project>/`. Every assistant message carries usage **and computed cost**:

```json
{
  "input": 7375, "output": 1, "cacheRead": 32, "cacheWrite": 0,
  "reasoning": 0, "totalTokens": 7408,
  "cost": { "input": 0.0022125, "output": 0.0000012, "total": 0.0022137 }
}
```

Messages are timestamped, so a run can be split into phases after the fact without needing a separate session per phase. The TUI footer and the `/session` command show the same totals live.

---

## Gotchas index

| Symptom | Cause |
|---|---|
| Every task costs $0.00 | `cost` omitted from `models.json` — defaults to all zeros |
| Long-context model truncates | `contextWindow` omitted — defaults to `128000` |
| Model missing from `/model` and `--list-models` | Auth not configured. Models load but stay unavailable |
| `command not found: pi` after install | Installed under a different Node version than the active one |
| An unrelated env var broke | `>>` appended to a file with no trailing newline |
| Published price or context is wrong | Read from a marketing page instead of `GET /v1/models` |

---

## References

- [Pi documentation](https://pi.dev/docs/latest) — [Custom Models](https://pi.dev/docs/latest/models) · [Session Format](https://pi.dev/docs/latest/session-format) · [Environment variables](https://pi.dev/docs/latest/environment-variables)
- [Nebius Token Factory docs](https://docs.tokenfactory.nebius.com) — [List models](https://docs.tokenfactory.nebius.com/api-reference/models/list-models)
- [Artificial Analysis — open weights](https://artificialanalysis.ai/models/open-source)

---

## Runbook — launch Pi and measure time to smile in Tenki

Use this to independently verify the workshop image without giving a key to the local machine, creating a public endpoint, scaffolding Astro, or deploying to Render.

> **Current release gate (2026-09-03): SSH/TTY PASSED; model-flow gate remains.** Tenki's managed SSH patch has been verified with Tenki CLI `v1.5.0` against both a plain sandbox and the private Pi image `mlxs8y/pi-nebius-token-factory@sha256:0fc40ae5ee9ba4a74cb64ae2554cc7685c1ce34e0d0ad86e3d0d187914bbc61c`. With inbound and outbound networking disabled, managed SSH returned `whoami → tenki`; an actual interactive shell allocated `/dev/pts/0`; Pi returned `0.84.4`; Render returned `v2.25.0`; and the baked Pi configuration files were present. Every test sandbox was terminated and no Nebius key was entered. The current CLI still lacks the docs-listed `--identity-file` flag, but it is no longer needed for Tenki-managed SSH. Real Nebius inference and the five-question Astro flow remain untested and must use a user-owned key only inside the verified interactive shell.

### Connection Gate — required before a Pi interaction

A run is eligible for the time-to-smile clock only when this command, from the launch machine, returns `tenki`:

```bash
"$TENKI_BIN" sandbox ssh --session "$NAME" -- whoami
```

If it returns any SSH error, terminate the sandbox immediately. Do not enter a Nebius key, do not use Pi, and do not treat the image as workshop-ready. The connection gate passed on 2026-09-03 with Tenki-managed SSH and an interactive `/dev/pts/0` shell, but repeat this non-secret check before every live run. Continue to the real model and five-question flow only when the facilitator explicitly approves use of their own Nebius key.

> **This runbook overrides the persistent-key advice in Step 2 for this test.** Do **not** put an attendee or workshop key in `~/.zshenv`, a `.env` file, Tenki `--env`, or any source-controlled file. You enter it only in the temporary sandbox shell, then discard that sandbox.

### What this run does

1. launches the prebuilt, private image below;
2. verifies Pi, Render CLI, and the Nebius configuration files without a credential;
3. passes the Connection Gate before an attendee enters any credential;
4. starts Pi's five-question landing-page intake in a new sandbox workspace;
5. confirms the Astro build and local preview; then
6. terminates the sandbox immediately and confirms the terminal state.

It does **not** create a public URL, Render service, Git commit, or deployment. Render is present only so Pi can prepare future deployment instructions after explicit approval.

### Prerequisites

- The Tenki CLI is installed and authenticated on the machine from which you run this.
- You have your own Nebius Token Factory key available to type into a temporary remote shell.
- You accept a short-lived sandbox charge. At Tenki's published rates, the 2 vCPU / 4 GiB RAM / 20 GiB disk maximum of 10 minutes is approximately **$0.02787 USD**. Terminate as soon as the checks pass; the five-minute idle timeout and ten-minute hard stop are safeguards, not cleanup.

Confirm authentication and that you are not already leaving a test sandbox running:

```bash
TENKI_BIN="$HOME/.local/bin/tenki"
"$TENKI_BIN" status
"$TENKI_BIN" sandbox list --json
```

The image was built from commit `fcc461bc2b261a0d8eb659e802719ed9f7a0cf94` on the `test/pi-nebius-tenki-image` branch. Use its immutable digest, not a mutable image tag:

```bash
IMAGE='mlxs8y/pi-nebius-token-factory@sha256:0fc40ae5ee9ba4a74cb64ae2554cc7685c1ce34e0d0ad86e3d0d187914bbc61c'
NAME="pi-nebius-verify-$(date +%Y%m%d-%H%M%S)"
```

### 1. Launch the bounded sandbox

```bash
"$TENKI_BIN" sandbox create \
  --image "$IMAGE" \
  --name "$NAME" \
  --cpu 2 \
  --memory-mb 4096 \
  --disk-size-gb 20 \
  --allow-inbound=false \
  --allow-outbound=true \
  --idle-timeout 5m \
  --max-duration 10m \
  --metadata purpose=pi-nebius-image-verification \
  --metadata lifecycle=disposable

"$TENKI_BIN" sandbox get --session "$NAME" --json
```

Proceed only after the session reports `RUNNING` or its equivalent ready state.

### 2. Verify the baked image, without a Nebius key

These checks do not call Nebius or expose a credential:

```bash
"$TENKI_BIN" sandbox exec --session "$NAME" --timeout 30s -- \
  bash -lc 'set -e; pi --version; render --version; test -s /home/tenki/.pi/agent/models.json; test -s /home/tenki/.pi/agent/settings.json; printf "image verification passed\\n"'
```

If this command fails, **do not** enter a Nebius key. Terminate the sandbox as described in [Step 5](#5-terminate-and-confirm-cleanup).

### 3. Start the five-question Pi session — only after the Connection Gate passes

Open an interactive shell in the sandbox:

```bash
"$TENKI_BIN" sandbox ssh --session "$NAME"
```

Inside the sandbox, type your key at the prompt. It is exported only to this shell and its Pi process; these commands do not write it to a file:

```bash
read -rs -p 'Nebius Token Factory key: ' NEBIUS_API_KEY
printf '\n'
export NEBIUS_API_KEY

cd /home/tenki/workspace
pi \
  --provider nebius-token-factory \
  --model MiniMaxAI/MiniMax-M3 \
  --no-context-files \
  --no-extensions \
  --no-skills \
  --no-prompt-templates \
  --tools read,bash,write \
  --skill /home/tenki/workshop-skills/landing-page-from-five-questions \
  "$(cat /home/tenki/START_LANDING_PAGE.md)"
```

Pi must ask **only question one** first, then wait. Its five-question sequence is:

1. problem and audience;
2. solution;
3. how it works;
4. benefits; and
5. pricing or call to action.

After all five answers, Pi must restate the brief, wait for approval, create the Astro project under `/home/tenki/workspace`, run `npm run build`, and start a local preview. It must not deploy.

When Pi exits, clear the temporary credential:

```bash
unset NEBIUS_API_KEY
exit
```

### 4. Time-to-smile clock and acceptance criteria

**Target:** eight minutes from Pi displaying question one to a working local Astro preview. This is a product target, **not yet a measured claim**.

Start the clock when Pi displays question one. Stop only when all of these are true:

- all five answers were collected one at a time;
- the user approved the summarized brief;
- an Astro project exists below `/home/tenki/workspace`;
- `npm run build` succeeds; and
- Astro prints a localhost preview URL.

Record the elapsed time, Pi and Astro versions, model ID, whether all five questions were asked, build outcome, and any recovery action. Do not record the Nebius key or Pi session files.

The sandbox is isolation from your Mac, not an outbound-network security boundary for a tool-using agent. Do not use untrusted prompts or web content, deployment credentials, Render/GitHub credentials, or prompts that ask Pi to use tools outside this bounded project workflow.

### 5. Terminate and confirm cleanup

Run this from your local terminal immediately after the check—whether it passed or failed:

```bash
"$TENKI_BIN" sandbox terminate --session "$NAME"
"$TENKI_BIN" sandbox get --session "$NAME" --json
```

**Pass condition:** the final state is `TERMINATED`. If the terminal returns a different state, repeat only the `sandbox get` check briefly; do not start a second sandbox while the first one may still be billable.

### Record only non-sensitive evidence

Record the sandbox name, image digest, Pi version, Render version, pass/fail result, and final `TERMINATED` state. Do **not** record the Nebius key, command environment, SSH transcript containing secrets, or model session files.

---

Built by [Frutero Club](https://github.com/fruteroclub) as part of Nebius Fellows DevRel work. Corrections and additions welcome — open an issue or a PR.
