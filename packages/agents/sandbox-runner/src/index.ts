import { makeRedis, publish, subscribe } from '@vibe/hermes';
import pino from 'pino';
import { applyPatches } from './patch-applier';
import { createE2BClient, isE2BConfigured } from './e2b-client';
import { SandboxPool } from './sandbox-pool';
import { estimateCost } from './cost-tracker';
const logger = pino({ name: 'sandbox-runner' });
const dedupe = new Set<string>();
const redis = makeRedis(process.env.REDIS_URL ?? 'redis://localhost:6379');
const e2b = createE2BClient();
const templateId = process.env.E2B_TEMPLATE_ID ?? 'base';
const pool = new SandboxPool(redis as never, e2b, templateId);
if (!isE2BConfigured()) logger.warn('E2B_API_KEY not configured; sandbox-runner in dry-run mode');
const cap = (txt: string) => txt.length > 65536 ? `${txt.slice(0, 65536)}\n[truncated; TODO M3-followup S3 upload]` : txt;
subscribe(redis, 'artifact.diff.created', async (env) => {
  const key = `${env.topic}:${env.message_id}`; if (dedupe.has(key)) return; dedupe.add(key);
  const buildId = (env.payload as { build_id: string }).build_id;
  if (!isE2BConfigured()) {
    await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.fs.applied', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'sandbox-runner', ts: new Date().toISOString(), payload: { build_id: buildId, milestone_id: (env.payload as { milestone_id: string }).milestone_id, files_applied: 0, total_bytes: 0 } });
    return;
  }
  const sandbox = await pool.getOrCreate(buildId);
  await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.lifecycle.started', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'sandbox-runner', ts: new Date().toISOString(), payload: { build_id: buildId, sandbox_id: sandbox.sandbox_id, started_at: sandbox.started_at, template_id: sandbox.template_id } });
  const applied = await applyPatches(e2b, sandbox.sandbox_id, (env.payload as { patches: Array<{ op: 'create' | 'modify'; path: string; content: string }> }).patches);
  await pool.touch(buildId);
  await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.fs.applied', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'sandbox-runner', ts: new Date().toISOString(), payload: { build_id: buildId, milestone_id: (env.payload as { milestone_id: string }).milestone_id, files_applied: applied.filesApplied, total_bytes: applied.totalBytes } });
});
subscribe(redis, 'sandbox.command.run', async (env) => {
  const key = `${env.topic}:${env.message_id}`; if (dedupe.has(key)) return; dedupe.add(key);
  const payload = env.payload as { build_id: string; command_id: string; command: string; timeout_ms?: number; working_dir?: string };
  if (!isE2BConfigured()) {
    await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.command.output', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'sandbox-runner', ts: new Date().toISOString(), payload: { build_id: payload.build_id, command_id: payload.command_id, stdout: '', stderr: '[sandbox-runner: E2B not configured]', exit_code: 127, duration_ms: 0 } });
    return;
  }
  const s = await pool.getOrCreate(payload.build_id);
  const out = await e2b.runCommand(s.sandbox_id, payload.command, payload.timeout_ms, payload.working_dir);
  await pool.touch(payload.build_id);
  await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.command.output', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'sandbox-runner', ts: new Date().toISOString(), payload: { build_id: payload.build_id, command_id: payload.command_id, stdout: cap(out.stdout), stderr: cap(out.stderr), exit_code: out.exitCode, duration_ms: out.durationMs } });
});
setInterval(async () => {
  const keys = await redis.keys('sandbox:*');
  for (const key of keys) {
    const buildId = key.replace('sandbox:', '');
    const stopped = await pool.stopIfIdle(buildId, 30 * 60 * 1000);
    if (stopped) {
      await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.lifecycle.stopped', schema_version: 1, correlation_id: buildId, producer: 'sandbox-runner', ts: new Date().toISOString(), payload: { build_id: buildId, sandbox_id: stopped.state.sandbox_id, ended_at: new Date().toISOString(), total_seconds: stopped.totalSeconds, est_cost_usd: estimateCost(stopped.totalSeconds) } });
    }
  }
}, 5 * 60 * 1000);
