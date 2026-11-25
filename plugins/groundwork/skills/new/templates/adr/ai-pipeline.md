# NNNN — AI pipeline
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
When model output drives product behavior, that output is untrusted input. Settle "can the system verify this" first, and settle the caps, the data lifetime and the cost records before the first demo.

## Decision
- **Output validation.** Check the schema and value ranges strictly and do not trust the output. Validation schema location: {{output_schema}}.
- **Injection boundary.** The output of a model that read external content (web · documents · user posts) cannot call money · permission · outbound actions directly; it goes through server validation or human approval (recommended default).
- **Separate AI service keys.** AI service keys sit in different environment variables · different accounts from the money-path keys, with low limits (recommended default).
- **When confidence is low.** Below the threshold, go to the safe side (human review). Threshold: {{confidence_gate}}.
- **Caps.** Hard caps per request on rounds · time · cost, with a comment saying the caps are not to be lifted lightly: rounds {{max_rounds}}, time {{max_seconds}}, cost {{max_cost}}.
- **Prompt cache.** Keep the system prompt the same on every call, and put changing values (current time · request id) in the user message, not in system. A changing value in front breaks the cache, and you pay the same cost every time. Compute the cost with the provider's cached-token accounting.
- **Pin the model.** Model ids and inference settings are pinned in one config place: {{model_config}}.
- **Data lifetime.** Load idempotently by stable id (loading the same content again gives the same result), and version vector collections. Retention period: {{retention}}.
- **Cost records.** Log usage as one line per call: `{{usage_log_format}}` (recommended fields: time, request id, model, input · output tokens, cost, result status). Memory · cost budgets and alerts: {{budget_alarms}}.

## Alternatives
- Use model output without validation: malformed or out-of-range values become actions as they are.
- Let the model decide with no caps: cost and time are unpredictable.

## Consequences
- When the output schema changes, the validation tests change too.
- A human review path (queue and screen) is needed.

## How to verify
- Check with schema tests that malformed or out-of-range output is refused.
- Check that a request stops when it goes over a cap.
- Confirm that one log line can reconstruct the cost of one call.
- With a prompt longer than the provider's minimum cache length, and caching on (for providers where it must be turned on), call the same prompt twice and check that the second call's usage shows cached input tokens. If 0, look at the length · cache settings first, then at whether a changing value got in front.
