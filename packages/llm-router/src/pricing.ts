export const MODEL_PRICING_USD_PER_1M = {
  'claude-opus-4-7': { input: 15, output: 75 },
  'claude-haiku-4-5-20251001': { input: 1, output: 5 }
} as const;
export const costUsd = (model: keyof typeof MODEL_PRICING_USD_PER_1M, inputTokens: number, outputTokens: number) => {
  const p = MODEL_PRICING_USD_PER_1M[model];
  return (inputTokens / 1_000_000) * p.input + (outputTokens / 1_000_000) * p.output;
};
