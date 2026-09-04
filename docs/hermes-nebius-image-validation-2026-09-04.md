# Hermes + Pi Nebius Tenki image validation — 2026-09-04

## Image

```text
mlxs8y/hermes-nebius-workshop@sha256:ae6ca95a59137540e66d6b2b417fb72395dcbfcd382a070de96f21093ae66b2d
```

The image was built from `feat/hermes-nebius-tenki-image` and validated without a Nebius credential.

## Verified

A disposable validation sandbox used two vCPUs, 4096 MiB memory, 20 GiB disk, inbound disabled, outbound disabled, a two-minute idle timeout, and a five-minute maximum duration. It was explicitly terminated; the final active-sandbox list was empty.

```text
Hermes Agent     0.21.0
Pi Coding Agent  0.84.4
Provider         Nebius Token Factory
Hermes default   nvidia/Nemotron-3-Ultra-550b-a55b
```

Pi registered these four image-defined models from the environment-backed configuration:

| Role | Profile | Model |
|---|---|---|
| Hermes orchestrator | Pro | `nvidia/Nemotron-3-Ultra-550b-a55b` |
| Hermes orchestrator | Budget | `MiniMaxAI/MiniMax-M3` |
| Pi developer subagent | Pro | `moonshotai/Kimi-K2.7-Code` |
| Pi developer subagent | Budget | `openai/gpt-oss-120b` |

The test also confirmed that both launchers refuse to run with no key, and that the budget calculator yields `$0.7500` for one million input plus one million output tokens on the Pi Budget profile.

## Credential boundary

Pi resolves `${NEBIUS_API_KEY}` at runtime from the temporary shell environment. The image, model configuration, source branch, and Tenki session configuration contain no provider key. The key must never be passed in an argument, `.env`, build environment, session `--env`, prompt, recording, or source file.

## $25 workshop budget

The image supports estimation and role-aware profile choice; it cannot itself impose a provider billing ceiling. A real $25 hard limit requires a verified Token Factory account/project spending control. If that control is unavailable, the facilitator must reconcile provider usage and stop the workshop at the $25 ceiling. Do not claim enforcement until the account control is verified.

Suggested operational allocation: $12 Hermes, $8 Pi, $5 reserve.

## Still required before participant use

1. Verify whether the intended Token Factory account can impose a $25 spend ceiling.
2. In a new, outbound-enabled disposable sandbox, enter a user-owned key in the interactive SSH shell only.
3. Run one small Hermes tool-use request and one bounded Pi `pi-subagent` request.
4. Capture provider-reported token usage and reconcile the estimate.
5. Terminate the sandbox immediately.
