import { makeRedis, publish, subscribe } from '@vibe/hermes';
import { createRouter } from '@vibe/llm-router';
import pino from 'pino';
import { z } from 'zod';
const logger = pino({ name: 'planner' });
const Milestone = z.object({ id: z.string().regex(/^[a-z0-9-]+$/), summary: z.string(), files: z.array(z.string()), acceptance: z.array(z.string()).min(1) });
const BuildPlan = z.object({ intent_summary: z.string(), target: z.enum(['next-supabase', 'expo', 'astro']), milestones: z.array(Milestone).min(1) });
export type BuildPlan = z.infer<typeof BuildPlan>;
export const processPlannerMessage = async (router: ReturnType<typeof createRouter>, env: { message_id: string; correlation_id: string; payload: { build_id: string; text: string } }, pub: typeof publish, redis: ReturnType<typeof makeRedis>) => {
  try {
    const completion = await router.complete({ role: 'planner', messages: [{ role: 'system', content: 'Return only BuildPlan JSON.' }, { role: 'user', content: env.payload.text }] });
    const plan = BuildPlan.parse(JSON.parse(completion.text));
    await pub(redis, { message_id: crypto.randomUUID(), topic: 'chat.agent.message', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'planner', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, agent: 'planner', text: `Plan drafted for ${plan.target}\n${plan.milestones.length} milestones proposed.`, kind: 'progress' } });
    await pub(redis, { message_id: crypto.randomUUID(), topic: 'build.plan.proposed', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'planner', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, plan } });
  } catch (error) {
    logger.error({ error }, 'planner failed');
    await pub(redis, { message_id: crypto.randomUUID(), topic: 'chat.agent.message', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'planner', ts: new Date().toISOString(), payload: { build_id: env.payload.build_id, agent: 'planner', text: 'Planner failed to generate a valid plan.', kind: 'final' } });
  }
};
const redis = makeRedis(process.env.REDIS_URL ?? 'redis://localhost:6379');
const router = createRouter({ anthropicApiKey: process.env.ANTHROPIC_API_KEY });
if (!process.env.ANTHROPIC_API_KEY) logger.warn('ANTHROPIC_API_KEY not set, planner running in fallback mode');
subscribe(redis, 'chat.user.message', (env) => processPlannerMessage(router, env as never, publish, redis));
