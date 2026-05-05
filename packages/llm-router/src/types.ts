export type ModelRole = 'planner' | 'codegen' | 'reviewer' | 'extractor';
export interface RouteUsage { input_tokens: number; output_tokens: number; cost_usd: number }
export interface RouteRequest { role: ModelRole; messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }>; schema?: object }
export interface RouteResponse { text: string; usage: RouteUsage }
