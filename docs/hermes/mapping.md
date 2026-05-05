# Hermes Topic Mapping
- chat.user.message: producer web; consumer planner
- chat.agent.message: producer any agent; consumer web
- build.requested: producer planner; consumer orchestrator(api)
- build.plan.proposed: producer planner; consumer reviewer
- build.plan.approved: producer reviewer; consumer codegen
- build.plan.rejected: producer reviewer; consumer web
- artifact.diff.created: producer codegen; consumer reviewer
- artifact.review.completed: producer reviewer; consumer orchestrator(api)
