# NNNN — Reliability of long-running flows
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
Flows that take long or wait for an outside confirmation, like settlement · payouts · webhooks · AI generation, get cut off midway. Unless they are built as state machines, stuck items pile up without anyone knowing, and with no operator actions such as cancel · retry, the DB gets fixed by hand.

## Decision
- Each flow is a **durable state machine**. Flows to run: {{flows}}.
- **A deadline per state.** Every unfinished state has a deadline; once it passes, the reconcile job continues it or escalates it to an operator. Every flow has explicit terminal states.
- **State transitions are one-way · idempotent.** Transition with compare-and-set, so retries · resends · out-of-order webhooks give the same result.
- **Outbox.** Anything sent outside first records the intent (with idempotency key · nonce), then sends. Sent but not yet confirmed is a state of its own.
- **Idempotent inbox.** The receiving side filters duplicates by message id.
- **Retention of finished records.** Outbox rows in terminal states and received message ids are deleted by a cleanup job once the retention period passes. Set the period longer than the longest window in which the outside can resend (delete earlier and a late duplicate gets through). The period goes in the spec.
- **Reconcile job.** Periodically match my records against the outside facts and send an alert on a mismatch. Reconcile interval: {{reconcile_interval}}.
- **Operator actions.** For each flow, the spec has a table of cancel · retry now · force complete · correct a wrong result · notify the user, and the effect of each action on downstream systems. Action list: {{operator_actions}}.
- No silent failures: features that depend on joins · flags · producers get an end-to-end acceptance test and a metric that counts misses · no-ops.

## Alternatives
- Handle it synchronously inside the request and let it be retried on failure: a cut in a long flow cannot be recovered.
- Track with logs, no state machine: finding stuck items becomes manual work.

## Consequences
- Each spec writes a states · deadlines · operator actions table.
- The admin screen needs action buttons and an audit record.

## How to verify
- Kill the process mid-flow and check that the reconcile job continues it.
- Test that sending the same message twice, and out of order, ends in the same final state.
- Confirm with a synthetic trigger that an item past its deadline comes up as an alert.
