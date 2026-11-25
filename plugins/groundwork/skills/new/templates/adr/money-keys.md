# NNNN — Money-moving keys
Status: proposed <!-- on approval, change it to `approved (YYYY-MM-DD)` -->
Date: YYYY-MM-DD

## Context
This project has keys that send assets to destinations not fixed in advance or that sign values deciding where money goes (settlement results · prices), or its app front end (web · native app) opens withdrawal · transfer · sell · order signing with a user session · wallet (an embedded wallet in the app included) (user-money actions). If one key · one admin session · one page script or app SDK is breached, money goes out for hours before anyone notices. This document settles what the keys can do, where they sign, the cap on how much can be lost, and how to stop.

## Decision
- **Key table.** The keys that move money or decide where money goes (settlement results · prices) are only the ones in the table below.

  | Key | What it can do | Where it is kept | Code path that uses it | Source of the values it signs |
  |---|---|---|---|---|
  | {{key_name}} | {{key_power}} | {{key_location}} | {{key_code_path}} | {{key_payload_source}} |

- **Signing location.** Signing happens only inside {{signing_service}}. Raw key material never sits in files · environment variables · logs.
- **Limits and balance cap.** Transfer totals cannot go over {{hourly_limit}} per hour · {{daily_limit}} per day. Over that, refuse and send an alert mail (B11 signal 6). The balance the server can send from is kept only up to {{hot_balance_cap}}, and the rest sits in {{cold_location}}.
- **Admin actions.** Admin actions that move money go through {{second_factor}}. Receiving addresses are picked only from the registered list ({{address_allowlist}}). No transfer to an arbitrary address is built into the admin API. Right before signing, verify the amount · receiving address · chain id · purpose again.
- **(operator key) Deterministic check before signing.** Every signature that decides where money goes, such as transfers · settlement results · prices, is checked again inside the signing adapter (the payout adapter if there is only a payout API) right before signing: target · function selector · value range · state (e.g. a result already settled, a payout already paid out or revoked). Do not sign on the caller's word (admin screen · DB row · webhook · a call list the server gave): results · prices never use the value the caller gave and are signed only when they equal the value fetched again from the key table's source (chain · external data the caller cannot write), and the state is read from that source too. If the source is a human judgment, sign only after a second approval with a different credential (second factor). Keep this line only in projects with an operator key.
- **(wallet key) Non-transaction signatures · permissions left on chain.** The signing service's policy covers not only transactions but also non-transaction signatures (EIP-7702 delegation · EIP-712 · messages), and refuses the kinds not in use. Delegations · approvals · roles stay on chain even after withdrawals are stopped or the signing service is turned off — build and drill the procedures for clearing delegations (a zero-address delegation) · replacing pending txs in advance in the key management method (KMS · MPC), and in an incident clear them before turning off the signing key (in a known case, funds kept leaking for hours through a delegation after withdrawals were stopped). Keep this line only in projects with an operator wallet key.
- **Stop switch.** One config value stops the actions that send money out (transfers, and with user-money actions also withdrawals · trades). How to turn it back on is in the spec's "P9 — Key table · limits · role table"; the order in an incident is `docs/runbooks/incident.md` C.
- **(contract) Roles.** {{contract_roles}}. Operating · withdrawing · adding admins are different roles, and admins cannot remove each other. The emergency pause role is {{pause_role}}. Keep this line only in projects with a contract.
- **(user-money actions) Gate outside the page.** {{user_money_gate}}. There is one gate for each place the signature goes (our server · external wallet · embedded wallet branches). A confirm · step-up on the app screen that page scripts · app SDKs can skip does not count as a gate (in a native app, 'outside the page' means outside the app). Silent signing only with scoped session keys. Signing requests are human-readable structured data (EIP-712). Keep this line only in projects with user-money actions.
- **(user-money actions) External code list.** The external code that runs on the page origin (for a native app, the app process) is only {{page_scripts}}. No session replay, analytics server-side first, social embeds in sandboxed iframes. A web front end loads external scripts from one place and turns them off with one flag (a native app's SDKs are bound into the app bundle and cannot be turned off at run time, so the list is kept short). Keep this line only in projects with user-money actions.
- **(native app · webview shell) OTA.** Use EAS Update during development. Before the production build that opens real money (security levels checkpoint 3), turn OTA off (`updates.enabled: false`) or put code signing on (private key outside CI). The reason: if `EXPO_TOKEN` leaks, JS can be pushed to every installed app and call the signing function directly. Keep this line only in native apps · webview shells with user-money actions.

## Alternatives
- Keep raw keys in server environment variables: the moment one server is breached, it is the whole amount.
- Put "transfer to an arbitrary address" in the admin API: once one admin session is hijacked, that API is a withdrawal window.
- Only a confirm · step-up on the app screen: once one page-origin script or app SDK is tainted, it skips the screen confirmation and calls the signing function directly.

## Consequences
- (operator key) What can be lost before anyone notices is bounded by the hourly limit and the hot balance cap. Keep this line only in projects with an operator key.
- (operator key) A large legitimate transfer is split up or goes through the procedure for changing the limit. Keep this line only in projects with an operator key.
- (wallet key) Key management service signing adds a little latency and cost. Keep this line only in projects with an operator wallet key.
- (user-money actions) Each action that sends money out goes through one more confirmation outside the page (step-up · wallet confirm dialog · provider policy), and less external code can load on the page · app. Keep this line only in projects with user-money actions.
- (native app · webview shell) With OTA off, urgent fixes also go out as store builds; with code signing, it costs an EAS paid plan and keeping the private key outside CI. Keep this line only in native apps · webview shells with user-money actions.
- (embedded-wallet branch) Real money (security levels checkpoint 3) does not open until the provider policy is in place. Keep this line only in projects where an embedded wallet calls the chain directly and the provider policy is not in place yet.

## How to verify
- (operator key) Limit test: just under the limit passes, over it is refused, concurrent requests are summed. Keep this line only in projects with an operator key.
- (operator key) A transfer to an unregistered address is refused. Keep this line only in projects with an operator key.
- (operator key) The signing adapter refuses a signature for a target · function outside the allowlist, a signature for a result whose state does not match (already settled), a result · price that differs from the value fetched again from the source, and a human-judgment result with no second approval. Keep this line only in projects with an operator key.
- With the stop switch thrown, transfer · withdrawal requests are refused.
- (contract) The operating role cannot withdraw · add admins, an admin cannot remove another admin, and while paused, transfers do not go through. Keep this line only in projects with a contract.
- (user-money actions) With the external script flag off, the page has no external scripts. Keep this line only in projects with a user-money web front end.
- (server branch) A withdrawal with no step-up token, or with one that fails verification, is refused, and an order outside the value range is refused. Keep this line only in projects where user-money actions pass through our server.
- (external-wallet branch) Signing requests are structured data, and no unlimited approve is created. Keep this line only in projects where an external wallet calls the chain directly.
- (native app · webview shell) In the production build that opens real money, `Updates.isEnabled` is false, or unsigned updates are refused. Keep this line only in native apps · webview shells with user-money actions.
- (embedded-wallet branch) In the provider's test environment, a transaction outside the policy (a contract not on the list · an amount over the cap) is not signed, a user session cannot remove or change the policy, and exporting the private key cannot get around the policy. Keep this line only in projects where an embedded wallet calls the chain directly.
