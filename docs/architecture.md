# Architecture

```text
codegen -> artifact.diff.created -> sandbox-runner -> sandbox.fs.applied -> test-runner

test-runner -> sandbox.command.run -> sandbox-runner -> sandbox.command.output
test-runner compares with Redis baseline:
  no regressions => test.run.completed(passed=true) + build.milestone.advance
  regressions => test.run.completed(passed=false) + build.regression.detected -> codegen retry
retry attempts >3 => codegen chat.agent.message(final halt)
```

Regression fence (M4):
- COMPLETED iff passed=true and regressions=[]
- baseline = last passing milestone test state by name
- test-set-shift => conservative baseline reset
- no bypass flag exists
