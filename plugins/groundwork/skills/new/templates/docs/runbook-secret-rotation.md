# Key rotation runbook
Status: draft
Date: YYYY-MM-DD

The procedure for replacing secret values (API keys · signing keys · DB passwords · webhook secrets) on a schedule or when exposure is suspected. The target list is the 'Key location' column of `docs/vendors.md` (if none, the names in `.env.example`). **Never write values in this document either.**

- Steps are split into `[you]` · `[agent]` (the agent does no push · prod commands · secret writes, only read checks, in-repo edits and gates) and written as "command → expected output". If the output differs, stop instead of going to the next step. An irreversible step says so and carries 'when not to use it', and the end has a rollback table and 'do not do'.

## Handling values
- Never put values in command arguments · chat · on screen (they stay in shell history and the conversation log). Take them with `read -rs v`, or with a script that reads the clipboard, puts the value in and clears it at once (macOS `pbpaste` → after putting it in, `pbcopy < /dev/null`). Pass them to tools on standard input (e.g. `printf %s "$v" | gh secret set NAME`).
- Check output is only format · length · HTTP code · version id and the first 8 characters of the hash (`printf %s "$v" | shasum -a 256 | cut -c1-8`). Whether two places hold the same value is also compared by these first characters.
- One secret, one source. A secret embedded in another value (the password in a DB connection URL, etc.) is not pasted in by hand; it is built from the source (a password IaC made, etc.). Kept separately in two places, they drift apart and startup fails. Encode it when putting it in a URL (a space is `%20`).
- (wallet key) Before putting in a real key for the first time, or replacing one, run the same sequence (create · put in · check a signature · clear the clipboard) end to end with a throwaway key. Keep this line only in projects with an operator wallet key.

## When
- Scheduled: 30 days before expiry, or every {{rotation_interval}}.
- At once: when a key showed up in logs · commits · chat · screenshots or exposure is suspected, when someone who knows the key leaves the team, when an external service in use announces a breach (the keys given to that service).

## Preparation
1. Check which environments (`{{environments}}`) hold the key to rotate and who uses it (the `docs/vendors.md` line if it exists, otherwise the comments in `.env.example`).
2. Issue a new key from the provider. Do not turn the old key off yet.
3. Decide whether downtime during rotation is acceptable. If there must be no downtime, check that the provider accepts two keys at the same time.
4. (wallet key) A new key is a new address — it is not rotated on a schedule. If it must change, stop transfers with the stop switch, wait until every pending tx of the old address is confirmed, move the balance · roles · receiving address list · provider policy to the new address, then turn it back on. Keep this line only in projects with an operator wallet key.

## Procedure
1. Put the new key into the secret store ({{secret_store}}). Do it per environment.
2. Developers who use a local env file each switch to the new value (never committed to the repo).
   - (P8) Delete the env copies in side-branch worktrees (under `.worktrees/` for a single repo, under the umbrella root's `.worktrees/` for an umbrella), and for each open side branch run `bash scripts/trunk.sh open <name>` again at the root to take the new value. Keep this line only in P8 projects.
3. How the app reads the new value: {{reload_method}}.
4. Check that it works: {{verification_command_or_page}}. Look for a success response and no failure logs.
5. Sweep: take the old value with `read -rs old` and check that `rg -uu -l -F -g '!node_modules' -f <({ printf '%s\n' "$old"; printf %s "$old" | python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read(),safe=""))'; }) <folders>` finds 0 in the local env files of every environment · every repo (sibling repos included) (it searches both the raw value and its URL-encoded form — a secret embedded in a URL takes the `%2F` · `%40` form. The value never goes out as an argument, and only file names are printed). It searches by the key value, not by URL, so forms embedded in wss · paths are caught too. CI · platform secrets you cannot read are judged by the time they were changed. Secrets are read at startup, so tasks (processes) started before the value changed still use the old value — compare with the task start times.
   - (P8) Put the root's `.worktrees/` in the sweep folders. An umbrella's side-branch copies are outside the repo folders, so searching only the repos misses them. Keep this line only in P8 projects.
6. Turn the old key off instead of deleting it (a way back remains). Before turning it off, check in the provider's usage records or logs, from the time every old task stopped after the restart, that the old key was used 0 times. If the same query shows 0 again 24 hours later, delete it. For a provider that cannot turn keys off (only delete · revoke) or has no per-key usage records, confirm 0 with the sweep of step 5 and the task start time comparison, then revoke at once (waiting for records keeps the old key alive forever).
7. Leave one line in `## Log` below (the next rotation date also in section 2 of the handoff, if there is one). If `docs/vendors.md` exists, update expiry · owner too.

## Extra steps for an exposure incident
- (wallet key) For a wallet key that moves money (or credentials that could sign with that key), do C 2–3 of `docs/runbooks/incident.md` (clear delegations · pending txs, move the balance) before turning it off. A key that is off cannot sign those txs. Keep this line only in projects with an operator wallet key.
- Turn the old key off first (accept the downtime — do not wait for the 0 check). Delete it per the 24-hour check of procedure step 6. For a provider that cannot turn keys off, revoke at once (rolling back means reissuing).
- Check the provider's records for the calls made with that key during the exposure window.
- Find out why the secret scanner missed it and strengthen its rules.

## Rollback
If the new key does not work, set the secret store value back to the old one (turn the old key back on if it was turned off) and find the cause. If the old key was already deleted, issue a new key again.

## Log
| Date | Key name (no value) | Environment | Reason (scheduled · exposure · departure · provider breach) | Next rotation |
|---|---|---|---|---|
