import { createE2BClient, isE2BConfigured } from '../../packages/agents/sandbox-runner/src/e2b-client';
import { writeFileSync } from 'node:fs';
const report: { passed: boolean; message: string } = { passed: true, message: '' };
const run = async () => {
  if (!isE2BConfigured()) { report.passed = true; report.message = 'Skipped: E2B_API_KEY not set'; writeFileSync('qa/sandbox-smoke/report.json', JSON.stringify(report, null, 2)); process.exit(0); }
  const c = createE2BClient();
  const s = await c.createSandbox(process.env.E2B_TEMPLATE_ID ?? 'base');
  await c.writeFile(s.sandboxId, '/workspace/hello.ts', "console.log('Hello, world!')");
  const out = await c.runCommand(s.sandboxId, 'bun /workspace/hello.ts');
  await c.closeSandbox(s.sandboxId);
  report.passed = out.stdout.includes('Hello, world!'); report.message = out.stdout || out.stderr;
  writeFileSync('qa/sandbox-smoke/report.json', JSON.stringify(report, null, 2));
  process.exit(report.passed ? 0 : 1);
};
run();
