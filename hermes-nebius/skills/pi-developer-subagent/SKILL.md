---
name: pi-developer-subagent
description: "Use when Hermes needs bounded implementation or code review."
---

# Pi developer subagent

Use `pi-subagent` when the main Hermes agent needs a scoped developer pass. Pi returns a final response to stdout; it is not a persistent service and does not inherit Hermes session memory.

## Profiles

- `pro`: Kimi K2.7 Code for multi-file implementation, debugging, and complex changes.
- `budget`: gpt-oss-120b for contained changes, review, tests, and simple fixes.

## Invocation

```bash
pi-subagent --profile budget --workdir /home/tenki/workspace/my-project --prompt 'Inspect the repository. Run the existing test suite. Return the smallest safe fix plan; do not edit files.'
```

For an approved implementation task, state the target files, acceptance test, and scope directly in the prompt.

## Boundaries

- The user must set `NEBIUS_API_KEY` in the current shell first. Never pass a key via a command argument, a file, `.env`, Tenki session configuration, or a prompt.
- The work directory must stay below `/home/tenki/workspace/`.
- Pi is a developer subagent, not the orchestrator. Hermes owns task decomposition, approval gates, and final synthesis.
- Keep subagent prompts bounded; request inspection before edits when the task is unfamiliar.
- Use `budget` by default; escalate to `pro` only for meaningful complexity or stalled reasoning.
