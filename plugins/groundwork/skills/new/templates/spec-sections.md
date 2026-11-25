# Required spec sections
Status: in use
Date: YYYY-MM-DD

For each module that is on, the spec must have the sections below. When calling brainstorming, pick only the sections of the modules that are on and pass them as the instruction "include this section in the spec". A spec with an empty section is not complete. For a server · API or a user-money front end, pass the 'Security — risky-feature table' section whatever the modules. Always pass the 'Hard rules · operating answers' section for the kickoff spec. If the stage 2 auth answer is 'needed', pass the 'Auth — session · permission lifetime' section too. A webview shell passes the 'Native app' section too.

## Hard rules · operating answers
- Write the stage 2 hard rules (never do these) exactly as given.
- The alert mail address (baseline answer 3). If P8 is on, the answers on the ledger · handoff · heavy-command lock and the cap on concurrent agents · push bundles and the CI minutes budget.
- Answers without an ADR live only here once the session is cut. The stage 4 `CLAUDE.md` and the stage 5 ledger · handoff read them from here.

## Security — risky-feature table
- Risky feature = moving money · assets · changing permissions · exporting or deleting data in bulk · automation that sends outward with no person involved.
- Table: feature · worst case · limit · anomaly signs (B11 signal no.) · who loses if it stops · auto stop (yes/no) · how to turn it back on.
- Auto stop is set per feature by asking "who loses if it stops".
  - A feature whose stop suddenly cuts users off and hurts them → keep it running and only send mail.
  - A feature whose stop hurts only the operator → it stops itself and sends mail.
  - User money leaving right now → stop.
  - If you decide against this rule, write `[judgement]` and the reason in that cell.
- In stage 4 the rows of this table move to the `docs/runbooks/incident.md` risky-feature table. From then on that table holds the current values.

## Auth — session · permission lifetime
- One verification point: HTTP · websockets · every call point that verifies on its own pass through the same verification function. A client SDK's block only hides the screen.
- With an external auth provider, verify only with the provider's public keys (JWKS) and add no shared-secret verification path. A token whose auth is not finished (second factor · device-registration-pending scope) is refused by the server even when its signature is valid.
- Lifetime: an absolute session expiry (refreshing never takes it past this time from the first login). Allowlists · roles · API key revocation are read again on every request, not once at login.
- Revocation: the path that cuts the sessions of one person · everyone and what survives the cut (refresh tokens · open websockets), and what to cut when the auth provider is breached. Disabling keys · sessions in incident runbook A uses this path.
- When linking accounts with OAuth, bind `state` to the session that started it and check it in the callback.
- Every path that takes an id checks on the server that the resource (wallet addresses · posts · threads included) belongs to the caller.

## P1 — Money flow and rounding points
- Draw the path money comes in and goes out from start to end (who, where, in which unit).
- Representation: integer minor units. Transmitted as a string or bigint. No floating point.
- Put every point where rounding happens in a table: point · direction (up/down) · who loses · the function used.
- Pick one ratio scale (0..1 or 0..100) and convert only on screen.
- Business values (fees · rewards · limits) in one table: where the value lives (one source) · copy to fix along with a change · deploy order.
- Results of actions that move money: not sent · sent (unconfirmed) · confirmed, the three states and the user's screen in each.

## P2 — States · deadlines · operator actions table
- A state table of long-running flows: state · entry condition · deadline · what happens when the deadline passes.
- Per state, the actions an operator can take and the permission needed.
- Outbox for messages to send, idempotency keys for received messages, the cycle of reconciliation jobs and what happens on a mismatch.
- How long finished outbox rows and received message ids are kept (longer than the longest period the other side can resend) and the cleanup job that deletes them.
- For what is deducted first (daily limits · quotas · reservations), a column for giving it back when a job fails, is cancelled or is an orphaned run: what is deducted when and on which path it is returned. If it cannot be returned, deduct after success.
- Scheduled job list: name · cycle · resolution (take user-visible scheduled times only in units the executing job can actually meet — every 5 minutes for a job that runs every 5 minutes) · how duplicate runs are prevented · failure alert.

## P3 — Per-endpoint permissions · invariants table
- Every endpoint (HTTP · websocket · upload · proxy), one line each: path · who calls it (anonymous/logged in/admin/service) · where ownership is checked · request count · body size limits · invariants that must always hold.
- For paths reachable anonymously, write the answer to the threat question (who can call what, how much).
- DB access default: row-level default deny and the list of exceptions.

## P4 — Output validation · caps · human review
- Per AI output: schema and value ranges · behavior on validation failure · fields not trusted.
- The criteria for sending low-confidence results to human review, and the review screen.
- Caps: call count · time · cost (per item · per day). How it stops when over.
- Data lifetime: idempotent loading with stable ids · retention period. The usage log format per call.
- The list of judgements · tool calls that external content (web · documents · user posts) reaches, and the server-validation · human-approval point of each.

## P5 — URL · language rules
- URL strategy: path prefix `/[lang]`, whether the default language may go unprefixed, hreflang · sitemap.
- The list of supported languages and how to add one. User content language is stored as data.
- Time: stored in UTC, shown in the viewer's locale. CJK font rules.

## P6 — Shared contracts
- What the apps share, in a table: where the brand · token source lives · the single schema of contract types · how to import it and pin its version.
- The order when a contract changes (source → generate → each app) and the compatibility period.

## P7 — Adapter boundaries and exit
- Per dependency: role · adapter folder and neutral interface · how to swap in a fake.
- Fallbacks and kill switches. Exit plan (candidates · switching order · start signal).
- Whether it is registered in `docs/vendors.md`.

## P9 — Key table · limits · role table
- Key table: key · what it can do · where it is kept · code path that uses it · source of the values it signs.
- Hourly/daily limits and the hot wallet cap.
- How receiving addresses are registered.
- The money-action stop switch and how to turn it back on.
- (contract) Role table and pause procedure.
- (user-money actions) Step-up gate and sponsorship policy · value ranges · signing request format · list of external code on the page origin (for a native app, external SDKs bundled into the app).

## Native app — version · compatibility rules
- Display version and build number rules, minimum supported version, forced update conditions.
- API backward-compatibility period and version notation. OTA runtime version policy.
- With a webview shell, the bridge version and allowlist between the shell and the web.
