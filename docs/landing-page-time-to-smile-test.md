# Landing-page time-to-smile test

## What this proves

This is a **local functional rehearsal**, not a security sandbox. It verifies Pi's Nebius Token Factory configuration and the five-question landing-page intake before any Tenki image build or Render deployment.

It does not create a Tenki Sandbox, a Render service, or a public URL. It does run a coding agent with shell access as your local macOS user, so use only a dedicated empty project directory and a key you are comfortable making available to that agent process.

## Acceptance target

**Time to smile:** a visible local Astro page within **8 minutes** of answering the first question.

Measure from the moment Pi asks question one until `npm run dev` displays a local URL. This is a target to validate, not a guarantee. Record the actual time, model used, and any correction needed.

## One-time isolated Pi setup

This repository intentionally does not overwrite your existing `~/.pi/agent` configuration. Your current local Pi configuration differs from this repository's Nebius configuration, so use the isolated directory below.

```bash
cd /Users/mel/workspaces/frutero/projects/devrel/nebius/code/pi-nebius-token-factory
bash scripts/configure-local-pi-nebius.sh
```

This creates `~/.pi/agent-tenki-workshop` with:

- `models.json` for Nebius Token Factory's OpenAI-compatible endpoint;
- `settings.json` selecting `MiniMaxAI/MiniMax-M3` by default; and
- the five-question landing-page skill.

The models file contains only the literal runtime reference `$NEBIUS_API_KEY`. It does not include a key.

## Run the rehearsal

Set your Nebius key only in the current terminal session, then start Pi. The launcher creates a new empty directory under `~/workspaces/tenki-pi-workshop/` and refuses to run in a non-empty project directory:

```bash
export NEBIUS_API_KEY='[your Nebius Token Factory key]'
bash scripts/start-landing-workshop.sh
```

The launcher disables discovered local context files, extensions, and prompt templates, then loads only the reviewed workshop skill. This reduces unreviewed local instruction loading; it does **not** constrain Pi's shell tool to that project directory. Do not use this local path with unknown repositories, untrusted web content, long-lived deployment credentials, or secrets you would not give to a coding agent.

Pi will ask, one at a time:

1. The problem and audience.
2. The simplest solution or offer.
3. How it works in three actions.
4. The visitor benefit.
5. Pricing or the desired call to action.

After Pi restates the brief, approve the local build. The agent must create a new Astro project with the current local `create-astro` package, so Astro is a dependency of that generated project, not a global install. The current npm registry version checked for this rehearsal is Astro `7.2.10`.

## Expected finish

Before declaring success, Pi must run `npm run build`. For a visual check it should then run:

```bash
npm run dev
```

Open the localhost URL Astro prints. Do not deploy during this test.

## Render boundary

The Tenki image recipe pins the official Render CLI `v2.25.0` and verifies its Linux AMD64 release checksum during image build. Pi may prepare Render-oriented deployment instructions, but it must not create a Render service or deploy unless explicitly authorized.

## Stop and clean up

Exit Pi with `Ctrl+C`. Remove the isolated configuration only if you no longer want the workshop setup:

```bash
rm -rf ~/.pi/agent-tenki-workshop
```

This removes configuration and skill files only. It does not affect your normal `~/.pi/agent` directory.
