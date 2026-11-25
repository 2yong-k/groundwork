# NNNN — Environment separation
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
If local · staging · prod share signing keys, privileged accounts, buckets, DBs or external service accounts, a mistake on one side touches the other side's assets. Environment separation is a structural decision, not a config switch, so it is made at the start. Even if prod is the only environment now, write down in advance the rules to keep when staging is added.

## Decision
- Environments are split into {{environments}} (recommended: local · staging · prod).
- Signing keys, admin accounts, oracle · payment accounts, buckets, DBs, external service accounts and push keys are made **separately per environment**. If a resource must be shared, put the environment name in every identifier, and add a guard that checks at the moment of use that the environment is right.
- The safe side is the default. Scripts and tools run as **non-production** when no environment is given, and refuse to start when the environment is empty or an unknown value (fail closed). Scripts that query · modify staging data (including ones for agent QA) read keys from the env file without printing the values, refuse deletes with no condition, stop if the target is not local · staging, and do not start the whole app (so the same job does not run twice alongside the deployed workers).
- The currently active environment shows in requests and on screen (admin tools send the environment with every request and the server checks it).
- Current environments: {{current_envs}}. When staging is added, apply the rules above as they are.
- (native app) App identifiers (iOS bundle id · Android package name) are also split into per-environment variants dev · staging · prod, installed side by side on the same device. Push · deep links · keys are per environment too. Keep this line only in projects with a native app or webview shell on.

## Alternatives
- One environment, split by a config switch: fastest, but nothing structurally stops an incident where keys and data mix.
- staging and prod share some resources: cheaper, but every shared resource needs an identifier namespace and a guard maintained forever.

## Consequences
- Making accounts and keys per environment takes initial work and cost.
- If one key leaks, the damage stays in that environment.
- Every new external service brings a check that asks "is there an account per environment".

## How to verify
- Pull the environment variable list per environment and compare that no secret value overlaps.
- Check that startup fails when an environment variable is left empty or set to a wrong value.
- Confirm that a script run with its defaults does not touch prod.
