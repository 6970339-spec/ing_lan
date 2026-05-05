import { describe, expect, it, vi } from 'vitest';
import { processApprovedPlan } from './index';
const env = { correlation_id: 'c', message_id: 'm', payload: { build_id: 'b', plan_id: 'p', milestones: [{ id: 'm1', summary: '', files: [], acceptance: ['x'] }] } };
describe('codegen',()=>{
it('publishes diff', async()=>{ const pub=vi.fn(async()=>1); await processApprovedPlan({complete:async()=>({text:JSON.stringify({milestone_id:'m1',patches:[{op:'create',path:'a',content:'x'}]}),usage:{input_tokens:1,output_tokens:1,cost_usd:1}})} as never, env, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
it('large patch sends final', async()=>{ const pub=vi.fn(async()=>1); await processApprovedPlan({complete:async()=>({text:JSON.stringify({milestone_id:'m1',patches:[{op:'create',path:'a',content:'x'.repeat(17000)}]}),usage:{input_tokens:1,output_tokens:1,cost_usd:1}})} as never, env, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(1); });
it('no milestones no op', async()=>{ const pub=vi.fn(async()=>1); await processApprovedPlan({complete:async()=>({text:'{}',usage:{input_tokens:0,output_tokens:0,cost_usd:0}})} as never, { ...env, payload: { build_id:'b', plan_id:'p' } }, pub as never, {} as never); expect(pub).toHaveBeenCalledTimes(0);});
it('rejects invalid patch op', async()=>{ const pub=vi.fn(async()=>1); await expect(processApprovedPlan({complete:async()=>({text:JSON.stringify({milestone_id:'m1',patches:[{op:'delete',path:'a',content:'x'}]}),usage:{input_tokens:1,output_tokens:1,cost_usd:1}})} as never, env, pub as never, {} as never)).rejects.toThrow();});
it('calls router', async()=>{ const pub=vi.fn(async()=>1); const complete=vi.fn(async()=>({text:JSON.stringify({milestone_id:'m1',patches:[{op:'modify',path:'a',content:'x'}]}),usage:{input_tokens:1,output_tokens:1,cost_usd:1}})); await processApprovedPlan({complete} as never, env, pub as never, {} as never); expect(complete).toHaveBeenCalled();});
});
