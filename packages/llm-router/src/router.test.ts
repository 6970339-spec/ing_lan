import { describe, expect, it } from 'vitest';
import { createRouter } from './index';
import { costUsd } from './pricing';

describe('router', () => {
  it('routes planner to opus', async () => {
    const router = createRouter({ anthropicDriver: { complete: async (m) => ({ text: m, input_tokens: 10, output_tokens: 20 }) } });
    const res = await router.complete({ role: 'planner', messages: [{ role: 'user', content: 'x' }] });
    expect(res.text).toBe('claude-opus-4-7');
  });
  it('routes extractor to haiku', async () => {
    const router = createRouter({ anthropicDriver: { complete: async (m) => ({ text: m, input_tokens: 1, output_tokens: 1 }) } });
    const res = await router.complete({ role: 'extractor', messages: [{ role: 'user', content: 'x' }] });
    expect(res.text).toBe('claude-haiku-4-5-20251001');
  });
  it('computes cost', () => {
    expect(costUsd('claude-opus-4-7', 1000, 1000)).toBeGreaterThan(0);
  });
  it('stub when no key', async () => {
    const res = await createRouter({}).complete({ role: 'planner', messages: [{ role: 'user', content: 'x' }] });
    expect(res.usage.cost_usd).toBe(0);
  });
  it('returns usage shape', async () => {
    const router = createRouter({ anthropicDriver: { complete: async () => ({ text: 'ok', input_tokens: 2, output_tokens: 3 }) } });
    const res = await router.complete({ role: 'reviewer', messages: [{ role: 'user', content: 'x' }] });
    expect(res.usage.input_tokens).toBe(2);
  });
});
