import type { Producer } from '@vibe/shared';
export interface ArtifactRef { uri: string; sha256: string; mime: string }
export interface Envelope<T> { message_id: string; topic: string; schema_version: 1; correlation_id: string; causation_id?: string; producer: Producer; ts: string; payload: T; artifact_refs?: ArtifactRef[] }
