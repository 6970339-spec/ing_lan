# Architecture

```text
web -> api -> chat.user.message -> planner -> build.plan.proposed
build.plan.proposed -> reviewer(plan) -> build.plan.approved/rejected
build.plan.approved -> codegen -> artifact.diff.created
artifact.diff.created -> sandbox-runner (lazy-create sandbox) -> sandbox.fs.applied
api -> sandbox.command.run -> sandbox-runner -> sandbox.command.output -> web SSE
sandbox-runner idle timer (30m) -> sandbox.lifecycle.stopped
```

Lazy sandbox contract: sandboxes are created by sandbox-runner on first artifact.diff.created for a build_id, not at build.requested.
