export interface ParsedTest { name: string; status: 'pass' | 'fail' | 'skip'; error?: string }
export const parseVitestOutput = (stdout: string, stderr: string): ParsedTest[] => {
  const lines = `${stdout}\n${stderr}`.split('\n');
  const out: ParsedTest[] = [];
  for (const line of lines) {
    if (line.includes('✓')) out.push({ name: line.split('✓').pop()?.trim() ?? 'unknown', status: 'pass' });
    if (line.includes('×')) out.push({ name: line.split('×').pop()?.trim() ?? 'unknown', status: 'fail', error: line.trim() });
    if (line.includes('↓')) out.push({ name: line.split('↓').pop()?.trim() ?? 'unknown', status: 'skip' });
    if (line.toLowerCase().includes('suite failed')) out.push({ name: 'suite-failure', status: 'fail', error: line.trim() });
  }
  return out;
};
