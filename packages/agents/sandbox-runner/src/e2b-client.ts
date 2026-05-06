import { Sandbox } from '@e2b/sdk';
export const isE2BConfigured = () => Boolean(process.env.E2B_API_KEY);
export interface E2BClient {
  createSandbox(templateId: string): Promise<{ sandboxId: string }>;
  writeFile(sandboxId: string, path: string, content: string): Promise<void>;
  runCommand(sandboxId: string, command: string, timeoutMs?: number, workingDir?: string): Promise<{ stdout: string; stderr: string; exitCode: number; durationMs: number }>;
  closeSandbox(sandboxId: string): Promise<void>;
}
export const createE2BClient = (): E2BClient => ({
  async createSandbox(templateId: string) { const s = await Sandbox.create({ template: templateId }); return { sandboxId: s.sandboxId }; },
  async writeFile(sandboxId: string, path: string, content: string) { const s = await Sandbox.connect(sandboxId); await s.filesystem.write(path, content); },
  async runCommand(sandboxId: string, command: string, timeoutMs?: number, workingDir?: string) { const s = await Sandbox.connect(sandboxId); const r = await s.commands.run(command, { timeout: timeoutMs, cwd: workingDir }); return { stdout: r.stdout, stderr: r.stderr, exitCode: r.exitCode ?? 1, durationMs: r.durationMs ?? 0 }; },
  async closeSandbox(sandboxId: string) { const s = await Sandbox.connect(sandboxId); await s.kill(); }
});
