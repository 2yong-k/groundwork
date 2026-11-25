# NNNN — Runtime and scheduled jobs
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
With two or more servers, or with scheduled jobs · workers · queues, the same job runs twice at once, and public requests and the core background loop starve each other in the same process. Assume several instances from the start and split the roles.

## Decision
- **Instance assumption:** always 2 or more. Scheduled jobs, queue consumers and state transitions are all protected by a lock or use a compare-and-set claim on a versioned row, and are idempotent.
- **Job execution:** every job runs through **one shared runner** (distributed lock + idempotency key + writes tied to the claim row). A bare scheduled job that skips the runner (`@Cron` · `setInterval` · registering with APScheduler directly) fails the check. Shared runner location: {{job_runner}}.
- **Separate web and workers:** split the roles from the start. The process that takes public requests and the scheduler · workers · core loop do not sit in the same failure domain. Role list: {{process_roles}}. When they are combined in one process, put resource caps on the public surface.
- **Run limits:** the shared runner enforces a time limit · max retries · cancellation on every run (the runner's defaults unless the job sets its own). A run cut off by a timeout or cancellation does not keep external calls going. Jobs that make external calls that cost money (paid APIs) also get a per-run cost cap. Settle a retention period and a deletion method for each cache · table a job writes.
- Bottleneck design: no global lock or single-threaded queue on the hot path. Partition key {{partition_key}}, latency budget {{latency_budget}}. Expected peak load: {{peak_load}}.
- The rate-limit store and the lock store are shared across instances: {{shared_store}}.

## Alternatives
- Assume one instance and scale later: a job that passed on one instance runs twice on the second.
- A scheduler in each process, with app code electing the leader: you maintain the election code yourself.

## Consequences
- Every job goes through the runner, so there is one way to write them.
- The minimum process count and the deploy units grow.

## How to verify
- Start the app as two instances and check that the same job runs only once.
- Put a bare scheduled job into the code on purpose and confirm that the check fails.
- Check that public requests keep answering when the workers stop.
- Check that a job over the time limit is cut off, and that a cancelled run makes no more external calls.
