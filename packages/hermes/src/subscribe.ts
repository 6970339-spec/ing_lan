import type Redis from 'ioredis';
import type { Envelope } from './envelope';
export const subscribe = async <T>(redis: Redis, topic: string, onMessage: (env: Envelope<T>) => void) => {
  await redis.subscribe(topic);
  redis.on('message', (_t, payload) => onMessage(JSON.parse(payload) as Envelope<T>));
};
