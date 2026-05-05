import { describe, expect, it, vi } from 'vitest';
import { processPlannerMessage } from './index';
const env = { message_id: 'm1', correlation_id: 'b1', payload: { build_id: 'b1', text: 'todo app' } };
describe('planner', () => {
  it('publishes progress and plan', async () => {
    const pub = vi.fn(async () => 1);
    const router = { complete: async () => ({ text: JSON.stringify({ intent_summary: 'x', target: 'next-supabase', milestones: [{ id: 'setup', summary: 's', files: ['a'], acceptance: ['b'] }] }), usage: { input_tokens: 1, output_tokens: 1, cost_usd: 1 } }) } as never;
    await processPlannerMessage(router, env, pub as never, {} as never);
    expect(pub).toHaveBeenCalledTimes(2);
  });
  it('on parse error publishes final only', async () => { const pub = vi.fn(async()=>1); await processPlannerMessage({ complete: async()=>({ text:'{}',usage:{input_tokens:0,output_tokens:0,cost_usd:0}})} as never, env, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
  it('accepts expo target', async () => { const pub = vi.fn(async()=>1); await processPlannerMessage({ complete: async()=>({ text: JSON.stringify({ intent_summary:'x',target:'expo',milestones:[{id:'a-b',summary:'s',files:['f'],acceptance:['ok']}] }),usage:{input_tokens:0,output_tokens:0,cost_usd:0}})} as never, env, pub as never, {} as never); expect(pub).toHaveBeenCalled(); });
  it('rejects bad milestone id', async () => { const pub = vi.fn(async()=>1); await processPlannerMessage({ complete: async()=>({ text: JSON.stringify({ intent_summary:'x',target:'astro',milestones:[{id:'Bad Id',summary:'s',files:['f'],acceptance:['ok']}] }),usage:{input_tokens:0,output_tokens:0,cost_usd:0}})} as never, env, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
  it('handles llm throw', async () => { const pub = vi.fn(async()=>1); await processPlannerMessage({ complete: async()=>{ throw new Error('x'); } } as never, env, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
});
