# NNNN — Shared contracts and brand
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
When there are more apps than the user app, such as admin · docs apps, each app grows its own colors, parts and wire types. Before building the second app, settle one place for the brand source and the contract source.

## Decision
- **One source for tokens · brand.** `design/tokens.json` is the source, and CSS variables and app themes are generated from it. Apps take it and do not edit it separately. Source location: {{token_source}}.
  - Single repo: a workspace package.
  - Umbrella (several repos): the front-end repo's `design/tokens.json` is the source, and the other repos copy it with `scripts/sync-tokens.sh`. Each repo's gate compares the source hash and fails if it differs (no registry · git dependency).
- **Contract types are generated from one schema.** Schema source (one of DB schema · OpenAPI · Zod): {{contract_source}}. No hand-copied wire types in each repo.
- **Ids and wire notation.** A branded type per id kind (even with the same string shape, like an auth provider subject and an internal user id, passing one in the other's place fails to compile). The wire notation (field name shape · date · amount format) is settled once, and only one boundary converts it to the in-app notation (e.g. the front end's fetch boundary).
- **Glossary.** Unit and naming rules (units of number fields, how names are written) live in one document: {{glossary_location}}.
- Parts are written down as shared between apps or app-only: {{shared_components}}.
- **(admin app) Admin actions.** Admin actions are named paths only, with no generic table editor · generic proxy (money · state tables too change only through named actions). Every admin path (GET included) passes one wrapper — session check · admin allowlist · role re-read on every request (not only at login) · Origin check of writes · environment match · one audit log line. The only exceptions are the ones written in the route list test. The confirm dialog shows the result that will change (results to settle · amount to send · count to delete). If a proxy is truly needed, refuse anything outside the path allowlist, and check the decoded value of id cells against a character set (URL parsing rewrites `\` and `..` later). Keep this line only in projects with an admin app.

## Alternatives
- A palette and parts per app: the more apps, the more they drift, and it is hard to undo.
- Copy types by hand: compile passes even when one side changed.

## Consequences
- When a token changes, every app that consumes it rebuilds.
- A contract generation step goes into CI.

## How to verify
- Change one token value and check that it shows in every app.
- Edit a copy on purpose and check that the sync check fails.
- Change the contract schema and check that the consumer's typecheck fails.
- Check that code passing a provider subject in the internal user id's place fails typecheck.
- (admin app) The existing session of an admin removed from the allowlist, and a non-admin session, get 403 on the next admin request. A route list test pins the wrapper and the exceptions of every admin path (GET included), and with a proxy, `..%5C` · `%2e%2e` paths are refused. Keep this line only in projects with an admin app.
