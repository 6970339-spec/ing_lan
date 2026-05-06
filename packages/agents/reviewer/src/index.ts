import { makeRedis, publish, subscribe } from '@vibe/hermes';
import { createRouter } from '@vibe/llm-router';
export const reviewPlan = async (env: { payload: { build_id: string; plan: { milestones: Array<{ id: string; acceptance: string[] }> } }; correlation_id: string; message_id: string }, pub: typeof publish, redis: ReturnType<typeof makeRedis>) => {
  const bad = env.payload.plan.milestones.length === 0 || env.payload.plan.milestones.some((m) => m.acceptance.length === 0);
  if (bad) return pub(redis, { message_id: crypto.randomUUID(), topic: 'build.plan.rejected', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'reviewer', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, plan_id: 'plan-1', reasons: ['Milestones/acceptance invalid'] } });
  await pub(redis, { message_id: crypto.randomUUID(), topic: 'build.plan.approved', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'reviewer', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, plan_id: 'plan-1', milestones: env.payload.plan.milestones } });
  await pub(redis, { message_id: crypto.randomUUID(), topic: 'chat.agent.message', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'reviewer', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, agent: 'reviewer', text: 'Plan approved', kind: 'progress' } });
};
export const reviewDiff = async (router: ReturnType<typeof createRouter>, env: { payload: { build_id: string; milestone_id: string; patches: Array<{ path: string; content: string }> }; correlation_id: string; message_id: string }, pub: typeof publish, redis: ReturnType<typeof makeRedis>) => {
  const blob = env.payload.patches.map((p) => `${p.path}\n${p.content}`).join('\n');
  const patterns = [/sk-[A-Za-z0-9]+/, /AKIA[0-9A-Z]{16}/, /eyJhbGc/, /rm -rf/, /DROP TABLE/i, /TRUNCATE/i, /force-push/i];
  const findings = patterns.filter((p) => p.test(blob)).map(() => ({ severity: 'high', message: 'Pattern violation detected' }));
  const llm = await router.complete({ role: 'reviewer', messages: [{ role: 'user', content: blob }] });
  if (llm.text.toLowerCase().includes('warning')) findings.push({ severity: 'medium', message: llm.text });
  await pub(redis, { message_id: crypto.randomUUID(), topic: 'artifact.review.completed', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'reviewer', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, milestone_id: env.payload.milestone_id, passed: findings.length === 0, findings } });
};
const redis = makeRedis(process.env.REDIS_URL ?? 'redis://localhost:6379');
const router = createRouter({ anthropicApiKey: process.env.ANTHROPIC_API_KEY });
subscribe(redis, 'build.plan.proposed', (env) => reviewPlan(env as never, publish, redis));
subscribe(redis, 'artifact.diff.created', (env) => reviewDiff(router, env as never, publish, redis));
