import { makeRedis, publish, subscribe } from '@vibe/hermes';
import { createRouter } from '@vibe/llm-router';
import { z } from 'zod';
const Patch = z.object({ op: z.enum(['create', 'modify']), path: z.string(), content: z.string() });
const Resp = z.object({ milestone_id: z.string(), patches: z.array(Patch) });
export const processApprovedPlan = async (router: ReturnType<typeof createRouter>, env: { payload: { build_id: string; plan_id: string; milestones?: Array<{ id: string; summary: string; files: string[]; acceptance: string[] }> }; correlation_id: string; message_id: string }, pub: typeof publish, redis: ReturnType<typeof makeRedis>) => {
  const first = env.payload.milestones?.[0]; if (!first) return;
  const result = Resp.parse(JSON.parse((await router.complete({ role: 'codegen', messages: [{ role: 'user', content: `Generate patches for ${first.id}` }] })).text));
  const size = result.patches.reduce((n, p) => n + p.content.length, 0);
  if (size >= 16 * 1024) {
    await pub(redis, { message_id: crypto.randomUUID(), topic: 'chat.agent.message', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'codegen', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, agent: 'codegen', text: 'Patch too large; TODO M3 sandbox-S3 wiring.', kind: 'final' } });
    return;
  }
  await pub(redis, { message_id: crypto.randomUUID(), topic: 'artifact.diff.created', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'codegen', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, milestone_id: result.milestone_id, patches: result.patches } });
};
const redis = makeRedis(process.env.REDIS_URL ?? 'redis://localhost:6379');
const router = createRouter({ anthropicApiKey: process.env.ANTHROPIC_API_KEY });
subscribe(redis, 'build.plan.approved', (env) => processApprovedPlan(router, env as never, publish, redis));
