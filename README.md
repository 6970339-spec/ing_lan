# Vibe Platform v0 + M2 + M3

## Setup
- Set `ANTHROPIC_API_KEY` in `.env` (optional planner fallback)
- Set `E2B_API_KEY` in `.env` for real sandbox execution
- Optional: `E2B_TEMPLATE_ID=base`
- `pnpm install`

## Sandbox lifecycle (M3)
```text
artifact.diff.created -> sandbox-runner lazy creates sandbox (first diff only)
patches applied -> sandbox.fs.applied
sandbox.command.run -> sandbox.command.output
idle 30 minutes -> sandbox.lifecycle.stopped (cost telemetry)
```

Dry-run mode: if `E2B_API_KEY` is unset, sandbox-runner does not call E2B and returns stubbed `sandbox.command.output` with exit_code 127.

## Dev
- `pnpm dev` runs web + api + redis/postgres (docker-compose)
- `pnpm validate` checks Hermes atomic topic invariants
