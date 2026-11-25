# NNNN — Public surface and threat model
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
APIs · uploads · websockets · proxies reachable without login can be called by anyone. Without a list of which paths are open and what guards them, even unused framework features and internal services end up exposed.

## Decision
- **Threat question.** What can an anonymous user call: {{anonymous_actions}}.
- **Deny by default.** Put request-count and body-size limits on as global defaults and relax them per path. The global limit middleware goes in the scaffold. Defaults: count {{default_rate_limit}}, body {{default_body_limit}}.
- **Ownership checks at the server boundary.** Bind resource owners to the authenticated identity, and verify signer = authenticated principal. Take input fields by allowlist. Do not trust owner · permission values the client sent.
- **DB access defaults to row-level deny.** New tables turn on row-level security in the migration that creates them, and internal tables deny everything. Public responses return only the fields needed: {{db_access_policy}}.
- Unused framework features and internal services are turned off or kept private. One function decides who the caller is, and the rate-limit key uses its result too.
- **Public path list.** Keep the table below always current (a new public path edits this table first).

| Path | Auth | Rate limit | Size limit | Cost |
|---|---|---|---|---|
| {{path}} | {{auth}} | {{rate}} | {{size}} | {{cost}} |

- (webview shell app) Bridge security: a bridge allowlist, load only your own origin, file access off, external links open in the system browser: {{bridge_policy}}. Keep this line only in projects with a webview shell on.

## Alternatives
- Limits set path by path, allow by default: a new path opens with no limits.
- Leave ownership checks to the client or UI: a direct call goes around them.

## Consequences
- Every new public path needs a table line and an HTTP check test.
- Legitimate bulk calls need an explicit per-path relaxation.

## How to verify
- HTTP tests per endpoint kind: check that no auth, someone else's resource, an oversized body and repeated calls are all refused.
- Compare the public path table with the actual route list.
- Check with a migration check that row-level security is on for new tables.
