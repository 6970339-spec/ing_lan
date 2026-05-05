import { readdirSync, readFileSync } from 'node:fs';
const topicsText = readFileSync('packages/hermes/topics.yaml', 'utf8');
const schemaText = readFileSync('packages/hermes/payloads.schema.json', 'utf8');
const mappingText = readFileSync('docs/hermes/mapping.md', 'utf8');
const fixtures = readdirSync('packages/hermes/fixtures').join('\n');
const producersConsumers = [readFileSync('packages/agents/planner/src/index.ts', 'utf8'), readFileSync('packages/agents/reviewer/src/index.ts', 'utf8'), readFileSync('packages/agents/codegen/src/index.ts', 'utf8')].join('\n');
const topics = ['chat.user.message', 'chat.agent.message', 'build.requested', 'build.plan.proposed', 'build.plan.approved', 'build.plan.rejected', 'artifact.diff.created', 'artifact.review.completed'];
for (const t of topics) {
  if (!topicsText.includes(t) || !schemaText.includes(t) || !mappingText.includes(t) || !fixtures.includes(t) || !producersConsumers.includes(t)) throw new Error(`Invariant failed for ${t}`);
}
