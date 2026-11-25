# Security levels and hardening table
Status: draft
Date: YYYY-MM-DD

There are no scheduled reviews. When one of the nine checkpoints below arrives, do its line in ①, raise the items in ② whose condition has come, and record it in ④. The incident response order is in `docs/runbooks/incident.md`.

## ① What to do at each checkpoint
`/groundwork:security-audit` ships with groundwork; the model cannot call it, so ask the user to type it. When a checkpoint arrives, ask for it with the scope · profile of the table below (e.g. `/groundwork:security-audit full audit standard`). Do not use another tool such as `security-review` in its place. If it cannot be typed right away, write it in section 3 of the handoff (if none, the 'Deferred' section of the active plan). Profiles are `quick | standard | deep`; the scope can be set (including the diff between two source refs), and it reads the previous run's coverage ledger to continue. Results stay outside the repo in `~/security-audit-skill/<repo>/run-<N>`.

| Checkpoint | `/groundwork:security-audit` | Also |
|---|---|---|
| 1 First beta release | full audit · standard | confirm all of ③ · read-only live config check · one backup restore drill · (deploy) build and schedule the daily check and fire each alert signal once with a synthetic event (`docs/runbooks/release.md` section 8) |
| 2 First general release | full audit · deep if P9 is on, otherwise standard (continuing the previous run) | review the hardening table again · (P9) one staging mock drill |
| 3 When real money first flows (mainnet deploy · turning on live payments), and when entrusted money passes the set amount | full audit · deep | check the conditions of the external-audit · bounty items in ② · (user-money actions) do not open real money while the 'required before checkpoint 3' rows of ② are not done |
| 4 A feature that changes a trust boundary: a new money path · new admin permission · new external input (content AI reads included) · new sensitive data | scoped audit (last audited ref..now, full audit if ④ is empty) · standard · after implementation, before deploy | update the `docs/runbooks/incident.md` risky-feature table (if section 0 exists) · the public path table (P3) |
| 5 When people join: giving permissions to the first teammate or contractor | none | ③ again (members · permissions · MFA) · turn on required PR review for main · (P9) check the multisig item |
| 6 When users grow and the infrastructure scales up | scoped audit (infra · deploy path) · standard | live config check · update the alert signal table · within 1 week of adding a big service, check costs on the spend screen (batches · scaling limits · idle resources) |
| 7 After an incident, or a big hack in the same industry | check that attack path in guidance mode → a scoped audit if needed | the result checked against our code in `docs/research/YYYY-MM-DD-<incident>-threat-model.md` |
| 8 When a serious defect or a malicious version becomes known in a package · framework · runtime · CI action version in use | none | `docs/runbooks/incident.md` B. If a malicious version was installed, go to checkpoint 7 |
| 9 When an external service in use (SaaS · Git hosting app · MCP server) announces a breach | none | in the ③ account table (and the external dependency register `docs/vendors.md`, if any), that service's line → cut the permissions it holds on us and grant them again · rotate the keys we gave it with `docs/runbooks/secret-rotation.md` · re-auth MCP · go in by typing the address yourself, not through mail links. If user data got out, go to checkpoint 7 |

- Live config check = with read-only credentials, check cloud permissions · public storage · buckets · open network · GitHub repo settings (branch protection · Actions permissions · deploy environment approvers). `/groundwork:security-audit` reads only source, so this is done separately.
- There is no audit per release — checkpoint 4 catches changes that move a trust boundary.

## ② Hardening items
Items not done now and raised when their condition comes. When it comes, change the status and write the date. Statuses are waiting · done · dropped. Lines whose tag (the parenthesis at the very start of the line) names something that is off are deleted from ② · ③ · the account table (`(P3)` · `(P4)` · `(P9)` · `(web UI)` · `(user-money actions)` · `(alert function)` · `(signal 4)` · `(deploy)` · `(daily watch)`). A phrase tag in ① deletes only that phrase.

| Item | Condition | Status | Date |
|---|---|---|---|
| External penetration test | checkpoint 2 or 3 | waiting | |
| Long-term log retention · paid monitoring | checkpoint 6 | waiting | |
| (alert function) Alert digest mail · on-call | checkpoint 5 | waiting | |
| (deploy) Switch CI → cloud to short-lived credentials (if the deploy path ADR could not; if it did, delete the line) | checkpoint 6 | waiting | |
| (deploy) Required approvers on the prod deploy environment (if the plan did not support turning it on; if on, delete the line) | when upgrading the plan · checkpoint 5 at the latest | waiting | |
| No force push · deletion on main (if the plan did not support turning it on; if on, delete the line) | when upgrading the plan · checkpoint 5 at the latest | waiting | |
| (P3) Bot blocking · WAF | checkpoint 6 | waiting | |
| (P4) Prompt injection test set | checkpoint 2 | waiting | |
| (P9) External contract · code audit | checkpoint 3 · entrusted money over {{audit_money_threshold}} | waiting | |
| (P9) Bug bounty | checkpoint 3 | waiting | |
| (P9) Multisig admin | checkpoint 5 | waiting | |
| (P9) Separate signing service | checkpoint 3 or 6 | waiting | |
| (P9) Redeploy contracts with mixed permissions (only when an already deployed contract mixes permissions) | checkpoint 3 | waiting | |
| (user-money actions) Server check of the sponsorship policy (if it could not be set at first) | checkpoint 3 | waiting | |
| (user-money actions) Embedded wallet provider's server-side policy (if ADR `money-keys` passed it on as `not possible — hardening table`; otherwise delete the line) | required before checkpoint 3 | waiting | |
| (user-money actions) Embedded-wallet policy measurement: in the provider's test environment, confirm that a transaction outside the policy · a policy change from a user session · private key export are all blocked (delete the line if the embedded wallet does not call the chain directly) | required before checkpoint 3 | waiting | |
| (user-money actions) OTA off in production builds (`updates.enabled: false`) or code signing (EAS Production plan or higher, private key outside CI) — ADR `money-keys` (delete the line unless a native app · webview shell) | required before checkpoint 3 | waiting | |
| (web UI) nonce CSP (delete the line for a user-money front end, which has it from the start) | checkpoint 2 | waiting | |
| (web UI) httpOnly cookie session (if it could not be done at first) | checkpoint 2 | waiting | |

Alerts passed on in stage 4 as "not possible — hardening table" get one line each in this table.

## ③ People · accounts list
What code cannot enforce. You do the "Now" items at the end of stage 4, and confirm everything under "Before checkpoint 1" before the first beta.

Now:
- [ ] MFA on cloud · Git hosting admin accounts
- [ ] Turn on Dependabot alerts
- [ ] Do not open or install repos others hand you (interview assignments · sample code · unfamiliar PRs) on your work machine (use a separate machine · cloud VM). Install dev tools by typing the official address yourself (no search ad links) — in a known case, a breach started with a forged installer and an interview assignment
- [ ] Do not keep credentials that can trigger a deploy (Git hosting write tokens · cloud admin keys) on a laptop for long — deploys go through CI (OIDC), human credentials through MFA sessions
- [ ] Give Git hosting apps · OAuth apps · MCP servers only the repos · read scopes they need, and cut unused connections at once — in a known breach of a docs-hosting service, the key it used to write to customer repos was on the exposed list
- [ ] (alert function) Confirm that one test alert mail reached your phone
- [ ] (daily watch) Confirm that daily watch (`.github/workflows/security-watch.yml`) failure mails reach you — the recipient is whoever last edited the cron line, so also check that the notification mail address of that GitHub account is `{{alert_email}}`
- [ ] Do not leave the monthly CI spending limit at $0 (Git hosting billing settings) — hitting the limit blocks deploys as well as CI, and jobs look like they failed with 0 steps. Set the limit to what you use and turn on budget alerts
- [ ] (deploy) Turn on monthly cloud budget alerts (to `{{alert_email}}`, B11 signal 8)
- [ ] Create the remote repo, do the first push, then confirm that every CI job is green (`gh run watch`) — `/groundwork:new` does not push, so `ci.yml` has never run. If red, fix it from the failed job logs (`gh run view --log-failed`)
- [ ] No force push · deletion on the main branch (if the repo is public or the plan supports it — otherwise ②)
- [ ] (signal 4) Turn on cloud audit alerts (to `{{alert_email}}`): {{cloud_audit_alert_steps}}

Before checkpoint 1:
- [ ] Fill the non-cloud admin account table below
- [ ] (deploy) After the first deploy, check in the real environment as in section 3 of `docs/runbooks/release.md`: for a server, that `commit` in the `GET /health` response equals the sha of the deployed tag; for screens, that the first screen loads — the local gate and CI do not see deploy config · environment values · domains
- [ ] Make separate read-only credentials for agents
- [ ] Archive unused repos
- [ ] Settle and fill the `tbd` cells of the runbooks and the external dependency register (if any) (`rg -n 'tbd' docs/runbooks docs/vendors.md`)
- [ ] For a public repo, confirm and prepare for scheduled workflows turning off after 60 days without activity

| Service | Login account | MFA | Members | Recovery method | Our permissions it holds (apps · OAuth scopes · keys we gave it) |
|---|---|---|---|---|---|
| Git hosting | | | | | |
| DNS · CDN | | | | | |
| DB dashboard | | | | | |
| Auth SDK dashboard | | | | | |
| App admin login | | | | | |
| Docs hosting · dev tool SaaS (MCP servers included) | | | | | |
| (alert function) Alert mail sending service | | | | | |

## ④ Audit records
Open items in audit results move to ledger `SEC-n` (if there is no ledger, the 'Deferred' section of the plan that handles the work).

| Date | Checkpoint | Profile | Scope (source ref) | Result path | Open item count |
|---|---|---|---|---|---|
