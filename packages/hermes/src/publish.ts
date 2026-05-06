import type Redis from 'ioredis';
import type { Envelope } from './envelope';
export const publish = async <T>(redis: Redis, envelope: Envelope<T>) => redis.publish(envelope.topic, JSON.stringify(envelope));
