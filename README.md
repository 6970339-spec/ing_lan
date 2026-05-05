# Vibe Platform v0 + M2

## Setup
- Set `ANTHROPIC_API_KEY` in `.env` (optional for fallback mode)
- `pnpm install`

## Routing rules
| Role | Model |
|---|---|
| planner | claude-opus-4-7 |
| codegen | claude-opus-4-7 |
| reviewer | claude-opus-4-7 |
| extractor | claude-haiku-4-5-20251001 |

## Dev
- `pnpm dev` runs web + api + redis/postgres (docker-compose)
- `pnpm validate` checks Hermes atomic topic invariants

## M2 working slice
1. Send: "build a TODO list app"
2. Planner posts summary + build.plan.proposed
3. Reviewer auto-approves or rejects
4. Codegen attempts first milestone and publishes artifact.diff.created
5. API relays diff to web as code block
