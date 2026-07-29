# Pi Coding Agent on Nebius Token Factory

A clean, reproducible setup for running [Pi Coding Agent](https://pi.dev) against
[Nebius Token Factory](https://tokenfactory.nebius.com) open-weight models —
with **per-token cost tracking that reports real dollars**, not zeros.

Pi already tracks token usage and cost natively. No extension, no proxy, no
wrapper. But two configuration defaults will silently give you wrong numbers,
and every secondary source we checked had at least one model's specs wrong. This
guide is the version that survives contact with those problems.

**Status:** steps 1–3 complete and verified. Step 4 in progress.

---

## Why this exists

If you want to know what an agentic coding task actually costs, you need three
things to be true at once:

1. The agent reports token usage per message. *Pi does, natively.*
2. The per-model prices are correct. *They default to zero — see step 4.*
3. The context window is correct. *It defaults to 128000 — see step 4.*

Miss #2 and every task reports **$0.00**. Miss #3 and a 1M-context model gets
silently clamped to 128K, so you are not measuring what you think you are
measuring. Neither failure raises an error.

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

`--ignore-scripts` disables dependency lifecycle scripts during install. Pi does
not require install scripts for normal npm installs, so this is free hardening.
Source: [pi.dev/docs/latest](https://pi.dev/docs/latest).

Verify:

```bash
pi --version
which pi
```

Verified against **0.82.1**. Note where the binary lands — with `nvm`, it goes
into the *active* Node version's prefix. Installing under one Node version and
running under another is a common way to get `command not found`.

---

## Step 2 — Set your API key

Put it in `~/.zshenv`, **not** `~/.zshrc`:

```bash
export NEBIUS_API_KEY="<your-key>"
```

zsh reads `~/.zshenv` for *every* shell, interactive or not. `.zshrc` is only
read by interactive shells, so anything non-interactive — scripts, daemons,
tooling that spawns its own shell — would not see the key.

### ⚠️ Do not append with `echo >>`

Two hazards, both real:

**Shell history.** `echo 'export NEBIUS_API_KEY="..."' >> ~/.zshenv` writes your
key into `~/.zsh_history` in plaintext.

**Missing trailing newline.** If the file does not already end in a newline,
`>>` concatenates onto the last line. You get this:

```
export SOME_OTHER_TOKEN=abc123export NEBIUS_API_KEY="..."
```

Now `SOME_OTHER_TOKEN`'s value silently swallows the entire export statement,
and `NEBIUS_API_KEY` is never defined. Two broken variables, no error message.

Use `read` with an explicit newline in the `printf` format instead — the key
never enters a command, so it never enters your history:

```bash
read -rs "k?Nebius key: "
printf 'export NEBIUS_API_KEY="%s"\n' "$k" >> ~/.zshenv
unset k
```

The `\n` in the format string is the fix: it always terminates the line, so the
next append cannot collide.

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

Each entry carries `id`, `context_length`, `pricing` (per-token decimal strings),
`architecture.modality`, `supported_features`, `regions`, and
`per_request_limits`.

### This endpoint is the only source of truth

We cross-checked the catalog against the Nebius marketing page, Artificial
Analysis, and a community relay's bundled model table. **Each one disagreed with
the API on at least one model.** Checked 2026-07-29:

| Claim | Source | API says |
|---|---|---|
| Kimi K3 context = 262K | community relay table | **1,048,576** |
| Nemotron-3-Ultra context = 262K | Artificial Analysis | **1,048,576** |
| MiniMax-M3 context = 1M | Nebius marketing page + AA | **8000** |
| Kimi-K2.7-Code context = 262K | relay table + AA | **8000** |

Prices, by contrast, matched the marketing page exactly.

Two takeaways. **Read `context_length` from the API before you configure
anything.** And **re-check before publishing any figure** — the catalog moves.

### Absent ≠ removed

`/v1/models` lists what is **currently servable**. A model pulled for
maintenance disappears from it exactly the same way a permanently delisted model
does, and nothing in the response distinguishes the two.

We hit this with `zai-org/GLM-5.2`, which is absent from the catalog. It is
easy — and wrong — to conclude it was discontinued. Check
[status.nebius.com](https://status.nebius.com) before assuming a missing model
is gone for good.

*(Note the domain: `status.nebius.com`, not `status.nebius.ai` — the latter does
not resolve.)*

Practical consequence for a benchmark: pin the model IDs you intend to use, and
if one goes missing mid-run, find out **why** before substituting. A model that
is merely down will come back, and swapping it out permanently changes what you
are measuring.

> The `8000` values on MiniMax-M3 and Kimi-K2.7-Code are unresolved. Both are the
> newest additions, which suggests placeholder metadata rather than a real limit,
> but we have not verified it. Until someone sends a >8K request and sees whether
> it is rejected, treat them as unusable for agentic work.

---

## Step 4 — Configure `models.json` (next)

Pi reads custom providers from `~/.pi/agent/models.json`.
Reference: [pi.dev/docs/latest/models](https://pi.dev/docs/latest/models).

```json
{
  "providers": {
    "nebius-token-factory": {
      "baseUrl": "https://api.tokenfactory.nebius.com/v1/",
      "api": "openai-completions",
      "apiKey": "$NEBIUS_API_KEY",
      "models": [ ... ]
    }
  }
}
```

`"$NEBIUS_API_KEY"` is environment interpolation — Pi resolves it at request
time, so the key stays out of the config file.

**The two defaults that will silently corrupt your data:**

| Field | Default | If you omit it |
|---|---|---|
| `cost` | all zeros | Pi reports **$0.00** for every task. Tokens still count; dollars do not |
| `contextWindow` | `128000` | A 1M-context model is clamped to 128K |

`cost` is expressed in **per-million-token rates**, matching what the API
returns once you multiply the per-token decimals by 1,000,000.

---

## Model roster

One model per lab, best-of-lab by
[Artificial Analysis](https://artificialanalysis.ai/models/open-source)
Intelligence Index v4.1. IDs and context windows verbatim from the API,
2026-07-29.

| Lab | Model ID | AA | Context | $/1M in | $/1M out | Region |
|---|---|---|---|---|---|---|
| Moonshot AI | `moonshotai/Kimi-K3` | 57 | 1,048,576 | 3.00 | 15.00 | eu-west2 |
| Z.ai | `zai-org/GLM-5.1` | 40 | 202,752 | 1.40 | 4.40 | eu-north1 |
| NVIDIA | `nvidia/Nemotron-3-Ultra-550b-a55b` | 38 | 1,048,576 | 1.00 | 3.00 | us-central1 |
| Alibaba | `Qwen/Qwen3.5-397B-A17B` | 34 | 262,144 | 0.60 | 3.60 | us-central1 |
| MiniMax | `MiniMaxAI/MiniMax-M2.5` | 34 | 196,608 | 0.30 | 1.20 | us-central1 |
| OpenAI | `openai/gpt-oss-120b` | 24 | 131,072 | 0.15 | 0.60 | eu-north1 |
| Nous Research | `NousResearch/Hermes-4-70B` | 10 | 131,072 | 0.13 | 0.40 | eu-north1 |

All seven report `tools` and `reasoning` support. All except `MiniMax-M2.5` also
report `json_mode` and `structured_outputs`.

`gpt-oss-120b` is from OpenAI but open-weight, so it belongs in an open-model
roster.

### Not usable as coding agents

These three report **no `tools` capability**, so they cannot drive an agent
regardless of their benchmark scores:

- `Qwen/Qwen2.5-VL-72B-Instruct`
- `openbmb/MiniCPM-V-4_5`
- `nvidia/Llama-3_1-Nemotron-Ultra-253B-v1` — has `json_mode`,
  `structured_outputs` and `reasoning`, but no `tools`

### One counterintuitive result

**`Hermes-4-70B` outperforms `Hermes-4-405B`** on the AA index — 10 vs 9 — at
$0.13/$0.40 against $1.00/$3.00. The 405B is roughly 8× the price for a lower
score. Picking best-of-lab surfaces this; picking biggest-of-lab hides it.

---

## Where cost data lands

Pi writes one JSONL file per session under `~/.pi/agent/sessions/<project>/`.
Every assistant message carries usage **and computed cost**:

```json
{
  "input": 7375, "output": 1, "cacheRead": 32, "cacheWrite": 0,
  "reasoning": 0, "totalTokens": 7408,
  "cost": { "input": 0.0022125, "output": 0.0000012, "total": 0.0022137 }
}
```

Messages are timestamped, so a run can be split into phases after the fact
without needing a separate session per phase. The TUI footer and the `/session`
command show the same totals live.

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

Built by [Frutero Club](https://github.com/fruteroclub) as part of Nebius Fellows
DevRel work. Corrections and additions welcome — open an issue or a PR.
