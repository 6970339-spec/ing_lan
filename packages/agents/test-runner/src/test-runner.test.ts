import { describe, expect, it } from 'vitest';
import { parseVitestOutput } from './vitest-parser';
import { detectRegression } from './regression-detector';

describe('vitest parser', () => {
  it('parses pass', () => expect(parseVitestOutput('✓ adds numbers', '')[0].status).toBe('pass'));
  it('parses fail', () => expect(parseVitestOutput('× fails badly', '')[0].status).toBe('fail'));
  it('parses skip', () => expect(parseVitestOutput('↓ skipped case', '')[0].status).toBe('skip'));
  it('parses suite failure', () => expect(parseVitestOutput('', 'Suite failed at setup')[0].name).toBe('suite-failure'));
});
describe('regression detector', () => {
  it('detects regression', () => { const r = detectRegression([{ name: 'a', status: 'pass' }], [{ name: 'a', status: 'fail', error: 'x' }]); expect(r.regressions.length).toBe(1); });
  it('counts new pass/fail', () => { const r = detectRegression([], [{ name: 'a', status: 'pass' }, { name: 'b', status: 'fail' }]); expect(r.newPasses).toBe(1); expect(r.newFailures).toBe(1); });
});
