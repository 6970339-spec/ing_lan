import OpenAI from 'openai';
export const makeOpenAiDriver = (apiKey: string) => {
  const client = new OpenAI({ apiKey });
  return client;
};
