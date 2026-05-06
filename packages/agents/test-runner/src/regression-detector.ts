import type { ParsedTest } from './vitest-parser';
export const detectRegression = (baseline: ParsedTest[], current: ParsedTest[]) => {
  const basePass = new Set(baseline.filter((t) => t.status === 'pass').map((t) => t.name));
  const currentByName = new Map(current.map((t) => [t.name, t]));
  const regressions = [...basePass].flatMap((name) => { const now = currentByName.get(name); return now && now.status === 'fail' ? [{ name, error: now.error ?? 'failed' }] : []; });
  const newPasses = current.filter((t) => t.status === 'pass' && !basePass.has(t.name)).length;
  const newFailures = current.filter((t) => t.status === 'fail' && !basePass.has(t.name)).length;
  return { regressions, newPasses, newFailures };
};
