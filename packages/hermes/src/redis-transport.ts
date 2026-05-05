import Redis from 'ioredis';
export const makeRedis = (url: string)=> new Redis(url);
