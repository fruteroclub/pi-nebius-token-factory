# Pi + Nebius Token Factory Tenki image

This template creates a **private Tenki image** for a pre-configured coding-agent workshop environment. It includes:

- Pi Coding Agent `0.84.4`;
- the Nebius Token Factory provider and supported model catalogue;
- a default model selection (`MiniMaxAI/MiniMax-M3`);
- a small `/home/tenki/workspace` directory; and
- the `pi-nebius` convenience command.

It deliberately does **not** contain a Nebius Token Factory API key. Tenki template build outputs and image snapshots must never include an attendee key.

## Build

A template build creates a private registry image and consumes Tenki resources. From this repository, after review and explicit approval:

```bash
tenki template build pi-nebius-token-factory --file .tenki/template.json
```

The command returns an immutable image digest. Record that digest in the workshop runbook; use it rather than a moving name for reproducible sessions.

## Launch a workshop sandbox

```bash
tenki sandbox create \
  --image '<private image digest from the build>' \
  --name 'bt-pi-demo' \
  --allow-inbound=false \
  --idle-timeout 15m \
  --max-duration 2h
```

The image is private by default. A build does not make it public or shared.

## Participant key setup

Inside the sandbox, an attendee adds their own key to the current shell only:

```bash
export NEBIUS_API_KEY='[their Nebius Token Factory API key]'
cd /home/tenki/workspace
pi-nebius
```

`pi-nebius` refuses to run without the variable and does not write it to a file. The variable ends when that shell ends. Do not put user keys in `--env`, template `build.env`, template runtime configuration, source control, screenshots, or workshop recordings.

## Verification

Before any live workshop, create one short-lived sandbox from the digest, run:

```bash
pi --version
test -s /home/tenki/.pi/agent/models.json
test -s /home/tenki/.pi/agent/settings.json
```

Then terminate it immediately after the check unless explicitly kept for a rehearsed demo.
