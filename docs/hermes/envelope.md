# Hermes Envelope

Hard rules:
- No inline secrets; KMS URIs only
- No inline large payloads; S3 + artifact_refs with sha256
- No direct agent-to-agent calls; everything via topics
- Idempotency required; consumers dedupe on (topic, message_id)
- Any topic change MUST touch all five places atomically: topics.yaml, payloads.schema.json, fixtures/, docs/hermes/mapping.md, and any producer/consumer agent files. Validator enforces.
