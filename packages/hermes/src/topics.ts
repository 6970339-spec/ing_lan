export const TOPICS = ['chat.user.message','chat.agent.message','build.requested','build.plan.proposed','build.plan.approved'] as const;
export type Topic = (typeof TOPICS)[number];
