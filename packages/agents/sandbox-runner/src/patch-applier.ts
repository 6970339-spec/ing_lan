import type { E2BClient } from './e2b-client';
export const applyPatches = async (client: E2BClient, sandboxId: string, patches: Array<{ op: 'create' | 'modify'; path: string; content: string }>) => {
  let totalBytes = 0;
  for (const patch of patches) { await client.writeFile(sandboxId, patch.path, patch.content); totalBytes += Buffer.byteLength(patch.content, 'utf8'); }
  return { filesApplied: patches.length, totalBytes };
};
