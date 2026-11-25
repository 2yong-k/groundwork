# Release runbook
Status: draft
Date: YYYY-MM-DD

The order for shipping to prod, checking what shipped, and rolling back when something goes wrong. What deploys automatically and what ships as a tag is set by ADR `release-model`. This document is the order that carries out that decision. **Never write secret values.**

- Each step names who does it as `[you]` · `[agent]`. The agent does no push · prod deploy · prod commands · secret writes, only read checks, in-repo edits (tags included) · gates. Steps are written as "command → expected output", and if the output differs, stop. An irreversible step says so and carries 'when not to use it' (the rollback table and 'do not do' are in section 4).
- When a step a person does has several commands, give it as a short guard script: `set -euo pipefail`, check the premises first (target sha · no tag · connected environment) and stop if they are off, and print the state before and after. A script that reaches prod refuses without a TTY, runs only once a set phrase is typed, and when it ends (failure · abort included) switches the tool connection back to a non-prod environment. Scripts live in the repo's `scripts/release/` and are committed (a temp folder is wiped on reboot).
- Before the first beta (`docs/runbooks/security-levels.md` checkpoint 1), short outages are fine: skip the zero-downtime steps (running side by side · draining · notices), but keep the security · money · rollback checks. Put them back once there are users.

## 1. Order
{{deploy_order}}. Docs · public copy (API reference · change notices) change after prod runs that behavior. First confirm with section 3 which commit prod runs, and if prod is behind main, note that lag in the spec.

## 2. Ship
Method: {{tag_deploy}}.

1. [agent] The session goes first: settle the commit to ship as a 40-character sha — the commit staging runs (staging's `/health` `commit`), or with no staging, the main commit whose gate is green. After `git fetch`, check whether `origin/main` is that sha; if not, tell you that the commits after it are not in this release. Look at the migrations · environment keys changed since the last tag (`git diff --stat <last tag> <sha> -- <migrations folder> .env.example`). If there are any, show the order of sections 1 · 6 first. Also look for date · season constants baked into the code (e.g. `rg -nw '20[0-9]{2}' <source folder>`, excluding tests · generated files). If dates · seasons already past are left, show them to you.
2. [agent] When you say to tag it, tag that sha: `git tag -a vX.Y.Z <sha> -m "…"`. Never delete or remake a version tag that already exists — if something needs fixing, it is a new version.
3. [you] Push the tag (`git push origin vX.Y.Z`), start the prod deploy by the method above and watch it to the end. If it fails, section 4.

## 3. Check
[agent] The session follows:
- The running commit equals the tag's sha: for a server, `commit` of `GET /health`; for a web UI only, `commit` of the deployed `version.json`; otherwise the commit in the deploy record (apply log · deploy transaction).
- The startup log has no errors, and the error count after the deploy (5xx · job failures) has not grown compared with before it.
- (server that warms up at startup) Treat the rollout as finished when `ready` of `GET /health` is `true` — requests before that hit cold instances. Keep this line only in servers that warm up heavy initialization at startup.
- If `commit` is `dev`, the deploy build did not put the sha in — do not roll back; fix section 7.
- If anything is off, recommend section 4 to you. If everything matches, do the release-time docs tidy (closed specs · plans to `docs/archive/`, checking the `CLAUDE.md` Mistakes log lines) in one commit.

## 4. Roll back
Migrations are not rolled back. With the expand → contract order, old code reads the new schema too.

| Stage | Symptom | Command | Who |
|---|---|---|---|
| Server · client deploy | `commit` is the previous tag's sha (the deploy did not run) | Do not roll back — look at section 2 step 3 (starting the deploy) and the trigger conditions of section 7 | you |
| Server · client deploy | `commit` is `dev` or an unknown sha | Do not roll back — look at section 7 | you |
| Server · client deploy | The new version fails to start · `/health` fails, or it came up with the tag's sha but errors grew | {{rollback_method}} | you |
| Expand migration | Apply fails · old code errors | Do not roll back — the fixed migration as a new version | you (the agent fixes it) |
| Secret · environment key | The new version fails to start for lack of a key | Put the key in and deploy again (section 6 order) | you |
| Docs · public copy | Describes behavior prod does not have | A commit that reverts that docs commit | agent |

(container image) If the deploy job fails with 'image already exists', do not rerun it — it may be an image someone planted under that tag in advance. Ship a new version and look at `docs/runbooks/incident.md` A. Keep this line only in projects that deploy as container images.

Do not use — old releases that read a deleted secret · environment key · external resource. Rolling back to one fails at startup. Add a line each time a key or resource is deleted.

| Release (tag · revision) | What it reads (deleted) | Date |
|---|---|---|

## 5. Hotfix
1. [agent] Branch from the tag prod runs (`origin/main` if there is no tag): `git worktree add .worktrees/hotfix -b hotfix/<name> <prod tag>`. Commits that are only on main are not dragged into prod.
2. [agent] Confirm the cause first, then fix it and commit together with a failing regression test. If a migration is involved, stop and settle the order with you.
3. [agent · you] Do section 2 steps 2–3 and section 3 with a new version.
4. [agent] On main, merge that branch (no rebase) and remove the worktree.

(P8) This branch is an exception to the trunk runbook — it must branch from the prod tag, so it does not use `trunk.sh open` · `merge`. After merging, look at the map with `bash scripts/trunk.sh` at the root. Keep this line only in P8 projects.

## 6. Secret · environment key order
- Add: put the key in the secret store first, then deploy the version that reads it.
- Remove: deploy a version that does not read the key, confirm with section 3, then delete the key. Before deleting, list the old releases that read the key under 'Do not use' in section 4.
- In the reverse order, startup fails. Changing only a key's value is `docs/runbooks/secret-rotation.md`.

## 7. Deploy workflow checklist
`/groundwork:new` does not make deploy workflows. When writing or editing a deploy workflow, and at the live config check of security checkpoint 1, go through the items below one by one.
- The prod job runs only on `v*` tags. A manual run from main against the prod environment does not reach prod either.
- Permissions are `contents: read`, and `id-token: write`, which gets the cloud token, is only on the deploy job. Actions are pinned to commit SHAs (the same as `ci.yml`).
- Deploys to the same environment run one at a time (concurrency per environment, without cancelling a deploy in progress).
- The cloud trust condition (OIDC subject) is narrowed to this repo's release tag refs.
- The deploy build puts the tag's sha in `commit` (`/health` · `version.json`). Without it, `dev` shows up and the section 3 check always mismatches.
- Do not turn off the step that waits after the deploy until the new version comes up healthy. It is the only net that catches a failed rollout.
- (container image) On the first attempt, it fails if that tag's image is already in the registry. A rerun reuses that image only when the digest the first attempt pushed (kept as job output · an artifact) equals the registry digest, and if the first attempt failed with 'already exists', it is not rerun (section 4). Keep registry tags non-overwritable, and ship prod by digest. Keep this line only in projects that deploy as container images.

## 8. Daily check (after launch)
A check that sees quiet degradation (retries · partial outages · memory growth · changes in provider behavior) before users do, once there are users. Build and schedule it before the first beta (security checkpoint 1).
- Bundle the queries into one numbered script (`scripts/daily-check.sh`, its argument the start of the UTC day, read-only credentials only). Pinning the date looks at the same window every day. Schedules are tied to the session and vanish when it ends, so write the time and command in section 2 of the handoff; a new session checks the schedule list first and re-arms it if it is missing.
- Find the query commands in the platform docs and fill them in. If unknown, `tbd — set before checkpoint 1`.

| # | Query | Command | If not 0 |
|---|---|---|---|
| 1 | 5xx count · the first few lines | tbd — set before checkpoint 1 | Write the cause in one line (results log below) |
| 2 | Retry · job failure count | tbd — set before checkpoint 1 | Write the cause in one line |
| 3 | Usage (request · call count) | tbd — set before checkpoint 1 | If it differs a lot from yesterday, look at why |
| 4 | 1-minute max of memory · response time; for memory also the daily max of the 7 days before | tbd — set before checkpoint 1 | Alert when it passes the threshold below. Below it, a daily memory max that rose 3 days in a row while number 3 did not is a leak suspect: move it to the ledger with a number, and do not raise the limit for it |
| 5 | Log volume · first · last time of the checked window | tbd — set before checkpoint 1 | If the window is empty, the 0s above are no verdict |

- **When you report 0, give number 5 with it.** A 0 from an empty log, or from only the first page, is not health. Judge 0 with an aggregate query or JSON output; text output is taken to show only the first page and is not used.
- **Resource alert threshold:** write at what % of the limit, as a 1-minute max, to alert. Also write the conditions for raising the limit (that window comes up often · it was killed for lack of memory · a growth after a change was measured), and do not raise it otherwise.
- **Results log:** at each check, write the date and the count per number as one line on the 'ongoing' line of handoff section 2, add an explanation to a non-zero count (e.g. how many were one external outage in which window), and add a removal condition to a watched line (delete the line if 0 through a given day). So the same alert is not investigated from scratch again. When it passes the threshold, move it to the ledger with a number.
- **Fire each alert signal once with a synthetic event.** If it watches an event name no rule has, it will not fire in 30 days either. Write the signals fired and the date as one line at the end of this section, and do it again each time a signal is added.

## 9. Several repos
Keep this section only in umbrella mode. Each release writes one line per repo and ships in the section 1 order. When one repo is rolled back, look at the repos later in the order too.

| Repo | What ships this time | Gate passed · sha checked | Order | Rollback |
|---|---|---|---|---|
