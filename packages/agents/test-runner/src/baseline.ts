import type Redis from 'ioredis';
import type { ParsedTest } from './vitest-parser';
export const loadBaseline = async (redis: Redis, buildId: string): Promise<ParsedTest[]> => {
  const raw = await redis.get(`build:${buildId}:test-baseline`); return raw ? JSON.parse(raw) as ParsedTest[] : [];
};
export const saveBaseline = async (redis: Redis, buildId: string, tests: ParsedTest[]) => redis.set(`build:${buildId}:test-baseline`, JSON.stringify(tests));
