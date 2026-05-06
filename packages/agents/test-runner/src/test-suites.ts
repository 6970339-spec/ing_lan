export type BuildTarget = 'next-supabase' | 'expo' | 'astro';
export const suitesByTarget: Record<BuildTarget, Array<{ name: 'typecheck' | 'lint' | 'test'; command: string }>> = {
  'next-supabase': [{ name: 'typecheck', command: 'pnpm typecheck' }, { name: 'lint', command: 'pnpm lint' }, { name: 'test', command: 'pnpm test' }],
  expo: [{ name: 'typecheck', command: 'npx tsc --noEmit' }, { name: 'test', command: 'pnpm test' }],
  astro: [{ name: 'typecheck', command: 'astro check' }, { name: 'lint', command: 'pnpm lint' }, { name: 'test', command: 'pnpm test' }]
};
