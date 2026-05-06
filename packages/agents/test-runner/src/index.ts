import { makeRedis, publish, subscribe } from '@vibe/hermes';
import pino from 'pino';
import { suitesByTarget } from './test-suites';
import { parseVitestOutput } from './vitest-parser';
import { detectRegression } from './regression-detector';
import { loadBaseline, saveBaseline } from './baseline';
const logger = pino({ name: 'test-runner' });
const redis = makeRedis(process.env.REDIS_URL ?? 'redis://localhost:6379');
const runCommand = async (correlationId: string, payload: { build_id: string; command_id: string; command: string; timeout_ms?: number; working_dir?: string }) => {
  await publish(redis, { message_id: crypto.randomUUID(), topic: 'sandbox.command.run', schema_version: 1, correlation_id: correlationId, producer: 'test-runner', ts: new Date().toISOString(), payload });
};
if (!process.env.E2B_API_KEY) logger.warn('E2B_API_KEY unset; real test runs require sandbox-runner configured E2B');
subscribe(redis, 'sandbox.fs.applied', async (env) => {
  const payload = env.payload as { build_id: string; milestone_id: string; target?: 'next-supabase' | 'expo' | 'astro' };
  const target = payload.target ?? 'next-supabase';
  const suites = suitesByTarget[target];
  const durations: Record<string, number> = { typecheck: 0, lint: 0, test: 0 };
  const parsedAll: ReturnType<typeof parseVitestOutput> = [];
  for (const s of suites) {
    const commandId = crypto.randomUUID();
    const started = Date.now();
    await runCommand(env.correlation_id, { build_id: payload.build_id, command_id: commandId, command: s.command });
    const output = await new Promise<{ stdout: string; stderr: string; exit_code: number; duration_ms: number }>((resolve) => {
      const handler = (topic: string, raw: string) => { if (topic !== 'sandbox.command.output') return; const msg = JSON.parse(raw) as { causation_id?: string; payload: { command_id: string; stdout: string; stderr: string; exit_code: number; duration_ms: number } }; if (msg.payload.command_id === commandId) { redis.off('message', handler); resolve(msg.payload); } };
      redis.on('message', handler);
    });
    durations[s.name] = output.duration_ms || Date.now() - started;
    if (s.name === 'test') parsedAll.push(...parseVitestOutput(output.stdout, output.stderr));
  }
  const baseline = await loadBaseline(redis as never, payload.build_id);
  const shift = baseline.length > 0 && parsedAll.length > 0 && baseline.every((b) => !parsedAll.find((c) => c.name === b.name));
  const calc = shift ? { regressions: [], newPasses: parsedAll.filter((x) => x.status === 'pass').length, newFailures: parsedAll.filter((x) => x.status === 'fail').length } : detectRegression(baseline, parsedAll);
  const passed = calc.regressions.length === 0 && calc.newFailures === 0;
  if (passed) await saveBaseline(redis as never, payload.build_id, parsedAll);
  await publish(redis, { message_id: crypto.randomUUID(), topic: 'test.run.completed', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'test-runner', ts: new Date().toISOString(), payload: { build_id: payload.build_id, milestone_id: payload.milestone_id, passed, regressions: calc.regressions, new_passes: calc.newPasses, new_failures: calc.newFailures, durations_ms: durations } });
  if (calc.regressions.length > 0) await publish(redis, { message_id: crypto.randomUUID(), topic: 'build.regression.detected', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'test-runner', ts: new Date().toISOString(), payload: { build_id: payload.build_id, milestone_id: payload.milestone_id, failing_tests: calc.regressions, retry_attempt: 1 } });
  if (passed && calc.regressions.length === 0) await publish(redis, { message_id: crypto.randomUUID(), topic: 'build.milestone.advance', schema_version: 1, correlation_id: env.correlation_id, causation_id: env.message_id, producer: 'test-runner', ts: new Date().toISOString(), payload: { build_id: payload.build_id, plan_id: 'plan-1', prev_milestone_id: payload.milestone_id, next_milestone_id: 'next' } });
});
