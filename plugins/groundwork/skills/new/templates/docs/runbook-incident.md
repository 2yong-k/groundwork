# Incident response runbook
Status: draft
Date: YYYY-MM-DD

The order to follow alone in the morning, top down, when an alert mail arrives or an incident is suspected. A mail from the app's alert function points at a section of this file in its first body line. GitHub daily watch (`security-watch`) failure mails go to B. Key rotation is in `docs/runbooks/secret-rotation.md`, checkpoints and hardening items in `docs/runbooks/security-levels.md`. **Never write secret values in this document.**

- Steps are split into `[you]` · `[agent]` (the agent does no push · prod commands · secret writes, only read checks, in-repo edits and gates) and written as "command → expected output". If the output differs, stop instead of going to the next step. An irreversible step says so and carries 'when not to use it', and the end has a rollback table and 'do not do'.

## 0. First 10 minutes
Keep this section only in server · API projects and projects with a user-money front end.
1. Read the mails in order of the severity in their subjects (the subject is `[severity][project][signal]`).
2. Find the feature in the risky-feature table below.
3. Decide whether to stop it now. The test is "who loses if it stops".
   - A feature whose stop suddenly cuts users off and hurts them → keep it running and watch.
   - A feature whose stop hurts only the operator → stop it.
   - User money leaving right now → stop it.
4. If you stopped it, tell users: {{status_notice_channel}}
5. Go to the section the mail's first line points at.

### Risky-feature table
This table holds the current values. The spec freezes on approval, so new risky features and limit changes go here first, before implementation.

| Feature | Worst case | Limit | Anomaly signs (B11 signal no.) | Who loses if it stops | Auto stop | How to turn it back on |
|---|---|---|---|---|---|---|
{{risk_table_rows}}

## A. Suspected account · key takeover
Keep this section only in server · API and infra · contract projects.
1. Disable the key · session.
2. Replace it with a new key as in `docs/runbooks/secret-rotation.md`.
3. Check in the app audit log what that key did and over what time range.
4. Compare with the cloud audit log (permission changes · new access keys · deploys from outside CI in the same window).

If an external service announced a breach, do 1–4 for each key given to that service, then go to checkpoint 9 of `docs/runbooks/security-levels.md`.

## B. Package defect

### B-1 A hole in a version
1. Check whether our lockfile · base image has that version (both main and the commit prod runs — for a server, `commit` of `GET /health`) and whether our code uses the defective path. If neither, write it in `## Log` and stop.
2. Put the fixed version in the new-version wait exception as an exact version, add a removal date (3 days later) as a comment and write it in section 2 of the handoff too (with no handoff, the agent tells you the date) — pnpm `minimumReleaseAgeExclude: ["<name>@<version>"]`, uv `exclude-newer-package = { <name> = false }` + the dependency `<name>==<version>`. For a base image, change `FROM` by hand to the digest of the fixed image — Dependabot docker PRs come weekly with a 3-day wait, so they can take up to ten days.
3. Run the gate.
4. Deploy.
5. On the removal date, delete the exception line.

### B-2 Malicious version
1. Check the lockfile history (`git log -p -- <lockfile>`) and CI logs for whether that version was ever installed. Tools fetched outside the lockfile (global installs · `npx` · `pnpm dlx` · `uvx`) are checked in CI logs and that machine's install records. If it never was, only make sure it does not enter the lockfile and write it in `## Log`.
2. If it was, rotate every secret that machine · CI could see as in `docs/runbooks/secret-rotation.md`.
3. Delete that machine's package cache and install folders (`node_modules` · virtual environments) and reinstall from a clean lockfile.
4. Go to checkpoint 7 of `docs/runbooks/security-levels.md`.

## C. Money-flow anomaly
Keep this section only in projects with P9 on.
1. Stop transfers with the money-action stop switch. With user-money actions, stop withdrawals · trades too.
   - (user-money actions) Compromised app code · SDKs skip an in-app switch. If ADR `money-keys` has an off-page gate (our server · provider policy · co-signing), refuse every transaction there too.
   - (native app · webview shell) If an app SDK or OTA compromise is suspected, go on to 'Incident response' in `docs/runbooks/store-release.md` (OTA rollback · emergency build).
2. (wallet key) Look at the permissions left on chain: if the server wallet has code (an EIP-7702 delegation) or pending txs, clear them with a zero-address delegation · a same-nonce tx **before turning off the signing key**. If they come back after clearing, treat that wallet as lost and move its roles to a new key.
3. Move the hot wallet balance to where the server cannot sign.
4. Check the change history of the limits · the receiving address list.
5. (contract) Pause the contract with the emergency pause role.
6. Turning it back on follows "P9 — Key table · limits · role table" of the spec.

## D. Data destruction · tampering
Keep this section only in server · API projects.
1. Stop writes.
2. Find the time of the last good backup.
3. Restore: {{restore_steps}}
4. Verify after restoring (core lists · counts · recent records match the backup time).

## E. Suspected external-script compromise
Keep this section only in projects with a user-money web front end.
1. Turn on the flag that turns external scripts off.
2. If user money is leaving right now, use the stop switch of C.
3. Find the time range and the affected users from CSP violation reports and withdrawal logs.
4. Invalidate the affected users' sessions.
5. Go to checkpoint 7 of `docs/runbooks/security-levels.md`.

## End
1. Write the one-line cause and what changed in the ledger (if `docs/ledger.md` exists) or the `## Log` table below.
2. Open `docs/runbooks/security-levels.md` at checkpoint 7.

## Log
| Date | Section | One-line cause | What changed | Opened checkpoint 7? |
|---|---|---|---|---|
