import Anthropic from '@anthropic-ai/sdk';
export const makeAnthropicDriver = (apiKey: string) => {
  const client = new Anthropic({ apiKey });
  return {
    async complete(model: string, messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }>) {
      const response = await client.messages.create({ model, max_tokens: 2000, messages: messages.filter((m) => m.role !== 'system').map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content })), system: messages.find((m) => m.role === 'system')?.content });
      const text = response.content[0]?.type === 'text' ? response.content[0].text : '';
      return { text, input_tokens: response.usage.input_tokens, output_tokens: response.usage.output_tokens };
    }
  };
};
