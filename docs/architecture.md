# Architecture

```text
web chat -> POST /api/builds/:id/messages -> api publishes chat.user.message -> Redis
planner(agent) -> llm-router(claude-opus-4-7) -> build.plan.proposed + chat.agent.message(progress)
reviewer(plan mode) -> build.plan.approved or build.plan.rejected
codegen(agent first milestone) -> llm-router(claude-opus-4-7) -> artifact.diff.created
reviewer(diff mode regex + llm) -> artifact.review.completed
api subscribes chat.agent.message/artifact.diff.created -> SSE -> web render
```
