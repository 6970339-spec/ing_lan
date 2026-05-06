import { describe, expect, it } from 'vitest';
import { applyPatches } from './patch-applier';
import { estimateCost } from './cost-tracker';
import { SandboxPool } from './sandbox-pool';

describe('sandbox runner units', () => {
  it('applies patches', async () => {
    const writes: string[] = [];
    const out = await applyPatches({ createSandbox: async()=>({sandboxId:'s'}), writeFile: async (_s,p,c)=>{ writes.push(`${p}:${c}`); }, runCommand: async()=>({stdout:'',stderr:'',exitCode:0,durationMs:1}), closeSandbox: async()=>{} }, 's', [{ op: 'create', path: 'a.ts', content: 'x' }]);
    expect(out.filesApplied).toBe(1); expect(writes.length).toBe(1);
  });
  it('cost positive', () => { expect(estimateCost(120)).toBeGreaterThan(0); });
  it('pool create', async () => {
    const mem = new Map<string, string>();
    const redis = { get: async (k:string)=>mem.get(k) ?? null, set: async (k:string,v:string)=>{mem.set(k,v); return 'OK';} };
    const pool = new SandboxPool(redis as never, { createSandbox: async()=>({sandboxId:'s1'}), writeFile: async()=>{}, runCommand: async()=>({stdout:'',stderr:'',exitCode:0,durationMs:1}), closeSandbox: async()=>{} }, 'base');
    const s = await pool.getOrCreate('b1'); expect(s.sandbox_id).toBe('s1');
  });
  it('pool reuse', async () => {
    const mem = new Map<string, string>([['sandbox:b1', JSON.stringify({ sandbox_id: 's2', started_at: new Date().toISOString(), last_activity: new Date().toISOString(), status: 'running', template_id: 'base' })]]);
    const redis = { get: async (k:string)=>mem.get(k) ?? null, set: async (k:string,v:string)=>{mem.set(k,v); return 'OK';} };
    const pool = new SandboxPool(redis as never, { createSandbox: async()=>({sandboxId:'new'}), writeFile: async()=>{}, runCommand: async()=>({stdout:'',stderr:'',exitCode:0,durationMs:1}), closeSandbox: async()=>{} }, 'base');
    const s = await pool.getOrCreate('b1'); expect(s.sandbox_id).toBe('s2');
  });
  it('idle stop', async () => {
    const old = new Date(Date.now() - 31 * 60 * 1000).toISOString();
    const mem = new Map<string, string>([['sandbox:b1', JSON.stringify({ sandbox_id: 's2', started_at: old, last_activity: old, status: 'running', template_id: 'base' })]]);
    const redis = { get: async (k:string)=>mem.get(k) ?? null, set: async (k:string,v:string)=>{mem.set(k,v); return 'OK';} };
    const pool = new SandboxPool(redis as never, { createSandbox: async()=>({sandboxId:'new'}), writeFile: async()=>{}, runCommand: async()=>({stdout:'',stderr:'',exitCode:0,durationMs:1}), closeSandbox: async()=>{} }, 'base');
    const s = await pool.stopIfIdle('b1', 30 * 60 * 1000); expect(s?.totalSeconds).toBeGreaterThan(0);
  });
  it('not idle no stop', async () => {
    const now = new Date().toISOString();
    const mem = new Map<string, string>([['sandbox:b1', JSON.stringify({ sandbox_id: 's2', started_at: now, last_activity: now, status: 'running', template_id: 'base' })]]);
    const redis = { get: async (k:string)=>mem.get(k) ?? null, set: async (k:string,v:string)=>{mem.set(k,v); return 'OK';} };
    const pool = new SandboxPool(redis as never, { createSandbox: async()=>({sandboxId:'new'}), writeFile: async()=>{}, runCommand: async()=>({stdout:'',stderr:'',exitCode:0,durationMs:1}), closeSandbox: async()=>{} }, 'base');
    const s = await pool.stopIfIdle('b1', 30 * 60 * 1000); expect(s).toBeNull();
  });
});
