# Tenki managed-SSH patch check - 2026-09-03

## Decision

The Pi + Nebius Tenki technical path is active again for controlled rehearsal. This is **not** an approval to describe Tenki as Burning Token participant infrastructure; that remains a separate program decision.

## Scope

A no-credential validation checked Tenki's repaired managed SSH path. Every sandbox used inbound and outbound networking disabled, `2 vCPU`, `4096 MiB` memory, disposable metadata, an idle timeout of two minutes, and a maximum duration of five minutes. Each session was explicitly terminated after its test.

## Results

| Check | Result |
|---|---|
| Plain Tenki sandbox - managed SSH `whoami` | Passed: `tenki` |
| Private Pi image - managed SSH command path | Passed: `tenki`, Pi `0.84.4`, Render `v2.25.0`, Pi config files present |
| Private Pi image - actual interactive managed shell | Passed: Ubuntu shell prompt, `/dev/pts/0`, Pi `0.84.4` |
| Active sandbox list after tests | Empty |

The verified private image is:

```text
mlxs8y/pi-nebius-token-factory@sha256:0fc40ae5ee9ba4a74cb64ae2554cc7685c1ce34e0d0ad86e3d0d187914bbc61c
```

## What remains unproven

- A user-owned Nebius key used inside the verified interactive shell.
- One real Nebius model response.
- The five-question intake, approved brief, Astro build, and local preview.
- Measured time to smile.

Do not pass any key through Tenki `--env`, an image/template, a source file, a session recording, or a shell startup file. Enter it only in the temporary interactive session after the non-secret connection gate passes.

## Source cleanup

The next image recipe removes the obsolete guest `openssh-server` installation and boot runtime. Tenki-managed SSH is now the only supported connection path. No replacement image was built as part of this check.
