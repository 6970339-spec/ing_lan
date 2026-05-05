import pino from 'pino';
import { makeAnthropicDriver } from './anthropic';
import { costUsd } from './pricing';
import type { ModelRole, RouteRequest, RouteResponse } from './types';

const logger = pino({ name: 'llm-router' });
const roleModel: Record<ModelRole, 'claude-opus-4-7' | 'claude-haiku-4-5-20251001'> = { planner: 'claude-opus-4-7', codegen: 'claude-opus-4-7', reviewer: 'claude-opus-4-7', extractor: 'claude-haiku-4-5-20251001' };

export const createRouter = (config: { anthropicApiKey?: string; anthropicDriver?: ReturnType<typeof makeAnthropicDriver> }) => {
  const anthropic = config.anthropicDriver ?? (config.anthropicApiKey ? makeAnthropicDriver(config.anthropicApiKey) : undefined);
  return {
    async complete(req: RouteRequest): Promise<RouteResponse> {
      const model = roleModel[req.role];
      if (!anthropic) {
        logger.warn({ role: req.role }, 'anthropic unavailable, returning stub response');
        return { text: '{"stub":true}', usage: { input_tokens: 0, output_tokens: 0, cost_usd: 0 } };
      }
      const out = await anthropic.complete(model, req.messages);
      const usage = { input_tokens: out.input_tokens, output_tokens: out.output_tokens, cost_usd: costUsd(model, out.input_tokens, out.output_tokens) };
      logger.info({ role: req.role, model, usage }, 'router completion');
      return { text: out.text, usage };
    }
  };
};
