import { describe, expect, it, vi } from 'vitest';
import { reviewDiff, reviewPlan } from './index';

describe('reviewer plan mode', () => {
  it('approves good plan', async () => { const pub = vi.fn(async()=>1); await reviewPlan({ correlation_id:'c', message_id:'m', payload:{ build_id:'b', plan:{ milestones:[{id:'a',acceptance:['ok']}] } } }, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(2); });
  it('rejects empty milestones', async () => { const pub=vi.fn(async()=>1); await reviewPlan({ correlation_id:'c', message_id:'m', payload:{ build_id:'b', plan:{ milestones:[] } } }, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
  it('rejects empty acceptance', async () => { const pub=vi.fn(async()=>1); await reviewPlan({ correlation_id:'c', message_id:'m', payload:{ build_id:'b', plan:{ milestones:[{id:'a',acceptance:[]}] } } }, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
  it('approved topic', async () => { const pub=vi.fn(async()=>1); await reviewPlan({ correlation_id:'c', message_id:'m', payload:{ build_id:'b', plan:{ milestones:[{id:'a',acceptance:['ok']}] } } }, pub as never, {} as never); expect(pub.mock.calls[0][1].topic).toBe('build.plan.approved'); });
  it('rejected topic', async () => { const pub=vi.fn(async()=>1); await reviewPlan({ correlation_id:'c', message_id:'m', payload:{ build_id:'b', plan:{ milestones:[] } } }, pub as never, {} as never); expect(pub.mock.calls[0][1].topic).toBe('build.plan.rejected'); });
});
describe('reviewer diff mode', () => {
  const env = { correlation_id:'c', message_id:'m', payload:{ build_id:'b', milestone_id:'x', patches:[{path:'a',content:'safe'}] } };
  it('passes safe diff', async () => { const pub=vi.fn(async()=>1); await reviewDiff({ complete: async()=>({text:'all good',usage:{input_tokens:1,output_tokens:1,cost_usd:1}}) } as never, env, pub as never, {} as never); expect(pub.mock.calls[0][1].payload.passed).toBe(true); });
  it('flags secret', async () => { const pub=vi.fn(async()=>1); await reviewDiff({ complete: async()=>({text:'ok',usage:{input_tokens:1,output_tokens:1,cost_usd:1}}) } as never, { ...env, payload:{...env.payload, patches:[{path:'a',content:'sk-abc'}]} }, pub as never, {} as never); expect(pub.mock.calls[0][1].payload.passed).toBe(false); });
  it('flags dangerous op', async () => { const pub=vi.fn(async()=>1); await reviewDiff({ complete: async()=>({text:'ok',usage:{input_tokens:1,output_tokens:1,cost_usd:1}}) } as never, { ...env, payload:{...env.payload, patches:[{path:'a',content:'rm -rf /'}]} }, pub as never, {} as never); expect(pub.mock.calls[0][1].payload.findings.length).toBeGreaterThan(0); });
  it('uses llm warning', async () => { const pub=vi.fn(async()=>1); await reviewDiff({ complete: async()=>({text:'warning: refactor',usage:{input_tokens:1,output_tokens:1,cost_usd:1}}) } as never, env, pub as never, {} as never); expect(pub.mock.calls[0][1].payload.passed).toBe(false); });
  it('publishes completed topic', async () => { const pub=vi.fn(async()=>1); await reviewDiff({ complete: async()=>({text:'ok',usage:{input_tokens:1,output_tokens:1,cost_usd:1}}) } as never, env, pub as never, {} as never); expect(pub.mock.calls[0][1].topic).toBe('artifact.review.completed'); });
});
