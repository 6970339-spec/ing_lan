import { z } from 'zod';
export const envelopeSchema = z.object({message_id:z.string(),topic:z.string(),schema_version:z.literal(1),correlation_id:z.string(),causation_id:z.string().optional(),producer:z.string(),ts:z.string(),payload:z.unknown(),artifact_refs:z.array(z.object({uri:z.string(),sha256:z.string(),mime:z.string()})).optional()});
export const validateEnvelope = (value: unknown)=> envelopeSchema.parse(value);
