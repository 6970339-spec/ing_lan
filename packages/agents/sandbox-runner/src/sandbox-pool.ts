import type Redis from 'ioredis';
import pino from 'pino';
import type { E2BClient } from './e2b-client';
import { estimateCost } from './cost-tracker';
const logger = pino({ name: 'sandbox-pool' });
export interface SandboxState { sandbox_id: string; started_at: string; last_activity: string; status: 'running' | 'stopped'; template_id: string }
export class SandboxPool {
  constructor(private redis: Redis, private client: E2BClient, private templateId: string) {}
  private key(buildId: string) { return `sandbox:${buildId}`; }
  async getOrCreate(buildId: string) {
    const raw = await this.redis.get(this.key(buildId));
    if (raw) return JSON.parse(raw) as SandboxState;
    const created = await this.client.createSandbox(this.templateId);
    const now = new Date().toISOString();
    const state: SandboxState = { sandbox_id: created.sandboxId, started_at: now, last_activity: now, status: 'running', template_id: this.templateId };
    await this.redis.set(this.key(buildId), JSON.stringify(state));
    return state;
  }
  async touch(buildId: string) { const s = await this.getOrCreate(buildId); s.last_activity = new Date().toISOString(); await this.redis.set(this.key(buildId), JSON.stringify(s)); return s; }
  async stopIfIdle(buildId: string, idleMs: number) {
    const raw = await this.redis.get(this.key(buildId)); if (!raw) return null;
    const s = JSON.parse(raw) as SandboxState;
    const idle = Date.now() - Date.parse(s.last_activity);
    if (idle < idleMs || s.status === 'stopped') return null;
    await this.client.closeSandbox(s.sandbox_id); s.status = 'stopped'; await this.redis.set(this.key(buildId), JSON.stringify(s));
    const totalSeconds = Math.max(1, Math.floor((Date.now() - Date.parse(s.started_at)) / 1000));
    logger.info({ build_id: buildId, sandbox_id: s.sandbox_id, seconds_alive: totalSeconds, est_cost_usd: estimateCost(totalSeconds) }, 'sandbox cost telemetry');
    return { state: s, totalSeconds };
  }
}
