import { Hono } from 'hono';
import pino from 'pino';
import { makeRedis, publish } from '@vibe/hermes';
const logger = pino({ name: 'api' });
const app = new Hono();
const redis = makeRedis(process.env.REDIS_URL ?? 'redis://localhost:6379');
const streams = new Map<string, ReadableStreamDefaultController<string>>();
const send = (buildId: string, data: object) => streams.get(buildId)?.enqueue(`data: ${JSON.stringify(data)}\n\n`);
app.post('/api/builds/:id/messages', async (c) => {
  const id = c.req.param('id');
  const { text } = await c.req.json<{ text: string }>();
  await publish(redis, { message_id: crypto.randomUUID(), topic: 'chat.user.message', schema_version: 1, correlation_id: id, producer: 'web', ts: new Date().toISOString(), payload: { build_id: id, text } });
  logger.info({ id }, 'message published');
  return c.json({ ok: true });
});
app.get('/api/builds/:id/stream', (c) => {
  const id = c.req.param('id');
  const stream = new ReadableStream<string>({ start(controller) { streams.set(id, controller); } });
  return new Response(stream, { headers: { 'Content-Type': 'text/event-stream' } });
});
redis.subscribe('chat.agent.message', 'build.plan.rejected', 'artifact.diff.created');
redis.on('message', (topic, payload) => {
  const parsed = JSON.parse(payload) as { payload: { build_id: string; text?: string; patches?: unknown } };
  if (topic === 'chat.agent.message') send(parsed.payload.build_id, { text: parsed.payload.text });
  if (topic === 'build.plan.rejected') send(parsed.payload.build_id, { text: 'Plan rejected' });
  if (topic === 'artifact.diff.created') send(parsed.payload.build_id, { text: `First milestone diff:\n\n\
\`\`\`json\n${JSON.stringify(parsed.payload.patches, null, 2)}\n\`\`\`` });
});
export default app;
