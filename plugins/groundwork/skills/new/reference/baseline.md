# Baseline — the twelve things every project gets (B1–B12)

In stage 2 **the only thing asked is one message on B1 · B7 and the security baseline (B10–B12)** (section C). The rest goes in at stage 4 without asking. The section A table says what goes in and as which file, section B how far it goes per project type, section D the sentences for CLAUDE.md and the fill rules (stage 4 details such as gate file locations and filling `ci.yml` · the secret rotation runbook are in `reference/baseline-scaffold.md`; the shared placeholder rules are section E). All paths are relative to this skill's folder (outputs are copied into the new project).

## A. Items · outputs

| No. | What | Output (this skill's file → new project) |
|---|---|---|
| B1 Environment separation | Local · staging · prod never share keys · signing wallets · buckets · DBs · external accounts. Even with only prod today, write down the rule for adding staging. An empty or unknown environment refuses to start, and scripts default to non-production. | `templates/adr/environments.md` → `docs/adr/NNNN-environments.md` (placeholders `{{environments}}` `{{current_envs}}`) |
| B2 Secrets | Secret-value scanning (pre-commit + CI), names only in `.env.example`, config type-checked at startup (no reading env directly in code), keys masked in logs · HTTP errors, a secret rotation runbook. | `templates/gates/gitleaks.toml` → `.gitleaks.toml` (with the same rules if you use a tool matched to the stack) · `templates/gates/pre-commit` → `.githooks/pre-commit` (check before commit, `reference/baseline-scaffold.md` "Secret-value hook") · `templates/gates/secrets.yml` → `.github/workflows/secrets.yml` (no path filter — docs-only pushes are scanned too) · config module (the builder writes it for the stack: validates env with a schema, refuses to start on failure — the test guard · server-only values · run-time values are in `reference/baseline-scaffold.md` "Config module") · `templates/docs/runbook-secret-rotation.md` → `docs/runbooks/secret-rotation.md` |
| B3 Strictness | TS strict (null checks included) · full lint (exhaustive-deps etc.) · strict ruff. Each app gets a unit test runner (front end included) and starts with 1 test. | Per-language config files (`tsconfig` strict · linter · `ruff`) + 1 test per app. No template — the builder writes them per the stack defaults table. Exclude `.worktrees/` from the tool configs (tsc · vitest · biome · eslint · knip) (side branch worktrees sit inside the root). Test commands run in a non-UTC time zone (e.g. `TZ=Asia/Seoul`) — so a UTC assumption breaks and shows both locally and in CI (UTC). Date math (business days · deadlines · seasons) happens only in one time module (even in projects with i18n off), and hardcoded date · season constants are hunted down with rg before release. For a server · API, set the validation tool globally: reject unknown fields · cap string and array lengths · enums accept only allowed values (NestJS: `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`, DTOs as classes only — `Omit<…> & {…}` · interfaces silently skip validation, so `OmitType`. pydantic: `ConfigDict(extra="forbid")` on the shared parent of request models, lengths with `Field(max_length=…)`, enums with `Literal` · `Enum`). The 1 test is at the HTTP level (not per handler): an unknown field · a too-long array · an out-of-range enum get a 4xx (400; FastAPI · pydantic 422) |
| B4 CI | A required check job before deploy (lint · types · tests), path filters · cancel duplicate runs, dependency security audit (by severity), unused-code detection. | `templates/gates/ci.yml` → `.github/workflows/ci.yml` (placeholders `{{cmd_install}}` `{{cmd_check}}` `{{cmd_audit}}` `{{cmd_deadcode}}`; fill rules in `reference/baseline-scaffold.md` "Filling `ci.yml`"). For a native app · webview shell uncomment the `eas-build` job of the same file; for web · PWA · webview shell, the `e2e` job |
| B5 Reads and failures | Lists carry ordering · pagination (keyset) and a "truncated" signal. One error-unwrapping helper keeps failures from turning into empty values · 0 (e.g. a result is either `{ok, data}` or `{error}`, so the caller gets the data only by unwrapping the error). A write while offline shows as a failure at once and what was written stays. Writes sent on reconnect are only the actions the spec names, written down together with the pending indicator · what happens when the tab closes · when the server rejects after reconnect. No money-moving actions among them. | CLAUDE.md rule lines (section D) + a helper skeleton (the builder writes it for the stack; three tests: a failed read does not become an empty array · discarding a write result shows as a failure (the write helper throws) · more rows than the page cap raise the "truncated" signal). DB · HTTP client imports only inside the helper (or adapter) folder — put the client package in the one-folder-allowed example of `reference/baseline-scaffold.md` 'Boundary import check'. The helper folder exports only functions that unwrap or throw errors, never the raw client object (exporting it slips past the import check and the error of `db.from(…).upsert(row)` gets dropped). The same check blocks the client call shape outside the folder (e.g. Supabase `bash scripts/rg-none.sh -n '\.from\([\x22\x27\x60]' src --glob '!**/db/**'`, where `db` is the helper folder). A best-effort write kept on purpose also lives only as a named function inside that folder, with a comment giving the reason. If the UI's data library by default holds writes and sends them on reconnect (check its docs), turn that off in code with 1 test (a write while offline fails instead of waiting). If it cannot be turned off, route only the actions that must not wait onto a path that fails when offline. |
| B6 Minimum observability | Request ids, global error handling that records 4xx/5xx, a health check that reports the running commit without external calls, 5xx · job failure alerts (through the B11 alert function). | Request-id middleware + global error handling + `GET /health` (the builder writes it for the stack. The response carries the commit sha `commit` and `version` baked in at build time, `dev` if none was — also make the slot where the deploy build bakes in the sha (Dockerfile `ARG` → `ENV` · a build-arg in the deploy command · reading the commit env the platform provides). 1 test: `commit` is not empty. Heavy initialization (models · indexes · big caches) runs off the event loop (workers · executors) and warms up at startup; `/health` does not wait for it and reports it as `ready` in the body (whether warm-up finished; it does not fail the check). Behind a load balancer, keep the server keep-alive longer than the LB idle timeout — the common pairing is Node 5s vs LB 60s, which gives 502s) · alerts are B11 |
| B7 Release model | What deploys automatically and what ships as a fixed tag. Migrations in expand → contract order. Deploy order. | `templates/adr/release-model.md` → `docs/adr/NNNN-release-model.md` (placeholders `{{auto_deploy}}` `{{tag_deploy}}` `{{deploy_order}}` `{{asset_strategy}}` `{{dev_db_policy}}`) · `templates/docs/runbook-release.md` → `docs/runbooks/release.md` (filling in `reference/baseline-scaffold.md` "Filling the release runbook") · with a DB, a migration folder and an apply command (`reference/baseline-scaffold.md` "DB migrations") · for a native app · webview shell, also `templates/adr/mobile-release.md` + `templates/docs/runbook-store-release.md` → `docs/runbooks/store-release.md` |
| B8 Docs | The `docs/{specs,plans,adr,runbooks,research,archive}` folders, what goes where · heads · closing · linking commits, a comment policy (write only the why, never history · ticket numbers). | Folders (`.gitkeep` in empty ones) + CLAUDE.md rule lines (section D) + `templates/docs-rules.md` (`{{docs_rules}}`) + the docs gate (`check-docs.sh` in `reference/baseline-scaffold.md`) |
| B9 Way of working | Size (S · M · L) and per-kind paths, a real-call check before declaring done. | The 'Size' · 'Kind' lines of `templates/docs-rules.md` |
| B10 Supply chain | Install exactly from the lockfile · reject versions published less than 3 days ago · an install-script allowlist · CI actions pinned to commit SHAs · base images pinned by digest · a daily dependency audit even with no commits | Config files (`reference/baseline-scaffold.md` "Supply-chain settings") · `templates/gates/security-watch.yml` → `.github/workflows/security-watch.yml` (placeholders take the same values as in `ci.yml`) |
| B11 Detection · response | Security alerts to one mailbox · admin and permission actions into an app audit log · an incident runbook you follow top-down in the morning | An alert function · an audit-log write function · two tests (`reference/baseline-scaffold.md` "Alerts and audit log") · `templates/docs/runbook-incident.md` → `docs/runbooks/incident.md` (filling in `reference/baseline-scaffold.md` "Filling the incident runbook and hardening table") |
| B12 Hardening | What to do at each of the 9 checkpoints (`/groundwork:security-audit` included) · hardening items to raise later · a list of people · accounts | `templates/docs/security-levels.md` → `docs/runbooks/security-levels.md` |

Stage 4 filling · wiring of the section A items (gate scripts · hooks · config module · runbooks · `ci.yml` · supply chain · DB migrations · alerts) is in `reference/baseline-scaffold.md`.

## B. Scope

Once the project type is set (stage 1 summary · client form), **items with an empty cell are not built.** A small CLI must not end up with a health route · middleware · ledger · handoff.

| No. | Server · API | UI | CLI · scripts · library | infra · contract |
|---|---|---|---|---|
| B1 Environment separation | ✓ | ✓ | Only when using external accounts · keys | ✓ |
| B2 Secrets | ✓ | ✓ | ✓ | ✓ |
| B3 Strictness | ✓ | ✓ | ✓ | Language linter · format only |
| B4 CI | ✓ | ✓ | ✓ | Format · validate jobs only |
| B5 Reads and failures | ✓ | If there are data reads · writes | If there are data reads | — |
| B6 Observability | ✓ | A client error reporting slot · `version.json` on the web | — | Alert slot only |
| B7 Release | ✓ | ✓ | If it deploys | ✓ |
| B8 Docs · B9 Way of working | ✓ | ✓ | ✓ | ✓ |
| B10 Supply chain | ✓ | ✓ | ✓ | Hold · watch only when there is a package manager |
| B11 Detection · response | Signals 1–5 (6 with P9, 7 with a user-money web front end) · audit log · alert function · the whole runbook | Signal 1 + client error reporting · runbook B (a user-money front end also gets signal 6 · alert function · runbook 0 · C, and on the web signal 7 · E — see how to read it below) | Signal 1 · runbook B | Signal 1 (if watched) · 4 (6 with contract + P9) · runbook A · B (+ C with P9) |
| B12 Hardening | ✓ | ✓ | ✓ | ✓ |

How to read it (where B5 · B6 · B11 drop out):
- **CLI · scripts · library:** no B6 (none of health route · request-id middleware · global error handling gets built). B5 adds the error-unwrapping helper only when there is code that reads data. B11 is only the daily watch (signal 1) and runbook B — no alert function · audit log.
- **infra · contract:** no B5. B6 is only the alert slot (one line naming where alerts go) — no health route · middleware. B3 is language linter · format only, B4 format · validate jobs only (the `deadcode` · `audit` jobs stay in `ci.yml` only when the tool exists).
- **UI:** B6 is only the client error reporting slot (a global error boundary sends to one place) and, on the web, a static `version.json` written by the build (`commit` · `version`, for checking deploys — together with the slot where the deploy build bakes in the sha). No server middleware · health route.
- **A user-money front end that is UI:** even though it counts as UI, B11 and the runbook take the server · API side per the notes above — the CSP report endpoint (signal 7) · alert function need server execution (serverless functions included), and so does step-up verification when a money action passes through our server. For actions where a wallet calls the chain directly, the gate is on the wallet side, not the server (an external wallet's confirm dialog, an embedded wallet's provider-side policy — the user-money action branches of `reference/modules/P9.md`). What cannot be built for lack of your own server goes into ADR `money-keys` as `not possible — hardening table`, with one more line in hardening table ②. A native app has no CSP reporting (signal 7) · external-script flag · runbook E — external SDKs are cut to the ADR `money-keys` list, and on suspected tampering it goes past runbook C's money-action stop switch to the severe-defect order of `docs/runbooks/store-release.md` (OTA rollback · emergency build).
- **Ask the B1 · B7 questions only for types where they are ✓/conditional.** If that cell is empty, drop that number from the message. Item 3 applies to every type, so even with both B1 · B7 empty the message goes out with item 3 alone.
- Umbrella mode puts in only this subset per repo kind. No health route · middleware in infra · contract repos.
- The heavy operations kit (`ledger` · `handoff` · `heavy.sh`) is not baseline; it appears only with P8 on. A small CLI has P8 off, so it does not get them.

## C. Baseline question message (B1 · B7 · security, one message)

Send it as one message after the stage 2 'Runtime and deploy target' question. A numbered list + recommended answers and reasons, ending with "as recommended, or just the numbers to change". Only numbers answered "change" get that branch asked separately, to the end. The answers fill the placeholders of ADRs `environments` · `release-model` and `{{alert_email}}`.

```
Here is what I propose for environments, releases and the security baseline.

1. Environment separation — split into local · staging · prod, with separate signing keys · accounts · buckets · DBs · external service accounts per environment.
   (Recommended · why: if a key leaks or something runs by mistake, the damage stays in that environment. Even with only prod today, adding staging follows the same rule.)
2. Release model — main deploys automatically to staging only; prod gets the same build checked on staging, as a fixed tag. Prod deploys start only from a tag a person made or a manual run. DB changes go expand → deploy code → contract.
   (Recommended · why: if a push to main becomes prod, prod changes unverified, and a destructive migration can land before the code.)
3. Security baseline — take only dependency versions published more than 3 days ago, pin CI actions to commit SHAs, and run a dependency watch every morning before 6. Security alerts go to one mailbox (`<git user.email>`).
   (Recommended · why: you learn about defects even with no commits, and even working alone you only check one inbox in the morning.)

Go as recommended? Tell me just the numbers to change.
```

The answers fill ADR `environments` (1) · `release-model` (2) and `{{alert_email}}` (3) per the table below. Replace `<git user.email>` in the message with the real value before sending; if that value is a no-reply address (e.g. `…@users.noreply.github.com`), replace it with `the mailbox you read — tell me which; your git e-mail is a no-reply address and receives no mail`. Placeholders the answers leave open take the table's recommendation, and the ADR says "recommended default".

| Placeholder | Value |
|---|---|
| `{{environments}}` | The answer to 1 (recommended: local · staging · prod). The same placeholder in the secret rotation runbook (B2) takes this value too |
| `{{current_envs}}` | The environments that actually exist now (from the stage 1 constraints · deploy target, e.g. local · prod) |
| `{{auto_deploy}}` | The answer to 2 (recommended: main → only staging deploys automatically). App builds of a native app · webview shell are not automatic (CI `eas-build` runs manually) — say so |
| `{{tag_deploy}}` | The answer to 2 (recommended: the same build checked on staging goes to prod as an immutable tag) |
| `{{deploy_order}}` | Not asked. Recommended: DB expand → server → client → contract (with several services, write their order too) |
| `{{asset_strategy}}` | Not asked. With a web UI, recommended: hash static file names and keep the previous build's files until the next deploy (CDN or an asset prefix path). With no web UI, `n/a` |
| `{{dev_db_policy}}` | Not asked. With a DB, recommended: develop and check against the staging DB and change the schema only through new migration files. Apply to staging only from the main checkout and commit the applied files on main (never apply from a side branch). Destructive commands such as reset · repair are run by a person. With no DB, `n/a` |
| `{{alert_email}}` | The answer to 3 (recommended: `git config user.email`, never a no-reply address — if the answer leaves the mailbox open, ask for it once). If a resume skipped section C, ask once in stage 4 when building B11. In CLAUDE.md, unless it is a server · API, delete the line holding this placeholder (B11) (a user-money front end that is UI keeps only the second sentence) |

- **If there is only one environment now**, change the recommended sentence of 1 to "Start with prod alone, and record in the ADR the rules to keep when adding staging".

### With a native app · webview shell (items added to B7)

Add sub-numbers under item 2. Each carries a recommended answer and reason (source: `reference/client-forms.md`).

```
2a. Minimum supported version and forced update — set a minimum supported app version and block anything older with an update screen. OS {{min_os}} or later.
    (Recommended · why: old app versions live on for months; without a way to block them, server changes leave broken apps behind.)
2b. API version rule — responses old apps relied on do not change during the support window; breaking changes ship as a new version.
    (Recommended · why: store review means you cannot fix the app at once.)
2c. Per-environment app identifiers — split dev · staging · prod into distinct iOS bundle ids · Android packages.
    (Recommended · why: identifiers cannot change after release, and split ones install side by side on one device, with push · deep links · keys split per environment too.)
2d. Store policy — build into the design from the start: in-app account deletion if accounts can be created, Sign in with Apple if there is third-party social login, in-app purchase rules for digital goods, a draft privacy label.
    (Recommended · why: getting caught in review delays the release and forces structural changes later.)
2e. Store accounts — make Apple Developer · Play Console organization (company) owned. With no company, change this number: start with personal accounts, and put in the plan the closed test before the first release (12 testers · 14 days) that a personal Play account (created after 2023-11-13) needs.
    (Recommended · why: organization enrollment needs a D-U-N-S number; a personal account shows your real name as the seller, and moving it to an organization goes through an account transfer process.)
```

- Replace `{{min_os}}` in 2a with the recommended value before sending (never send it as is).
- The answers fill the "(native app)" section of ADR `release-model`, ADR `mobile-release` and `docs/runbooks/store-release.md` (`templates/docs/runbook-store-release.md`) per the table below. "Not asked" rows take the `reference/client-forms.md` section B recommendation (EAS-managed credentials) and are asked only in follow-ups to changed numbers.

| Placeholder | Value |
|---|---|
| `{{min_os}}` | The answer to 2a. Recommended value = the minimum iOS · Android versions the Expo SDK of the day supports (write the date you checked alongside) |
| `{{api_version_rule}}` · `{{min_supported_version_rule}}` | The answers to 2a · 2b (recommended: responses old apps relied on do not change during the support window and breaking changes ship as a new version · the server sends down the minimum supported version and older apps get an update screen) |
| `{{api_compat_window}}` | The answer to 2b (recommended: 90 days after raising the minimum supported version) |
| `{{ios_bundle_id}}` · `{{android_package}}` | The answer to 2c. The identifier rule is `reference/client-forms.md` section C (no suffix = prod) |
| `{{bundle_id_dev}}` · `{{bundle_id_stg}}` · `{{bundle_id_prod}}` · `{{package_dev}}` · `{{package_stg}}` · `{{package_prod}}` | Per environment by the same rule as 2c (`.dev` · `.staging` · no suffix) |
| `{{iap_policy}}` | The answer to P1 item 5 if it was asked, else the answer to 2d. With no digital goods payments, `n/a` |
| `{{links_and_push}}` | The answer to 2d (recommended: link domains and push keys separate per environment, keys behind the server) |
| `{{runtime_version_policy}}` | Not asked. Recommended: bump the runtime version when native code changes |
| `{{credential_owner}}` · `{{store_account_owner}}` | The answer to 2e. Recommended: the admin of the organization (company) owned account; with no company, the user's personal account |
| `{{upload_key_backup}}` · `{{upload_key_backup_location}}` | Not asked. Recommended: EAS-managed credentials, with the backup copy in the organization's secret store |
| `{{store_exit_plan}}` | Not asked. The recommended sentence in the template's parentheses |
| `{{ota_rollback_method}}` | Not asked. Recommended: republish the previous update in EAS Update |
- With P1 on and native, the in-app purchase item is asked on the P1 module side (`reference/modules/P1.md`). Here 2d only names it.
- A webview shell, on top of 2a · 2b, includes "the contract between shell and web (bridge version)" in the 2b sentence. The web part goes live at once; the shell takes the store path.

## D. CLAUDE.md rule lines

Short sentences that go under 'Conventions' in `templates/CLAUDE.md.tmpl`. The project's share of `reference/conventions.md` `## Engineering rules` is in the template's 'Conventions'. The umbrella CLAUDE.md takes only B1 · B2 · B7 · B8 · B10 · B12 and the P8-off line, and with P8 the side-branch line · session-start line (lines shared by the repos).

| No. | Sentence |
|---|---|
| B1 | Environments (local · staging · prod) never share keys · accounts · buckets · DBs. An empty or unknown environment refuses to start, and scripts run as non-production when given no environment. |
| B2 | Secret values never go in code · logs · docs · chat. `.env.example` holds names only, and config is read only from a module validated against a schema at startup (no reading env directly in code). Key rotation: `docs/runbooks/secret-rotation.md`. |
| B5 | Lists carry ordering · pagination (keyset) and a "truncated" signal. Never turn a failed read into an empty value · 0; go through the error-unwrapping helper. |
| B5 writes | A write while offline shows as a failure at once and what was written stays. If the data library by default holds writes and sends them on reconnect, turn that off in code (TanStack Query: mutation `networkMode: 'always'`). Actions sent on reconnect are only those the spec names, and never money-moving ones. |
| B7 | Prod gets the same build checked on staging, as a fixed tag. Migrations go expand → contract, and a push alone never applies a destructive change. |
| B7 DB | Change the schema only with new SQL files in the migration folder, and apply with `pnpm db:push` (uv: `make db-push`). Applying runs type generation after it. Generated files are committed, never edited by hand. |
| B8 | Docs live only in `docs/{specs,plans,adr,runbooks,research,archive}`. Comments give only the why (no history · ticket numbers). |
| B10 | Install dependencies exactly from the lockfile and take no version published less than 3 days ago (an urgent security patch is the only exception, for the exact version, through the `docs/runbooks/incident.md` B procedure). Pin CI actions to commit SHAs. |
| B11 | Admin and permission actions go into the audit log, and alerts go to one place, `{{alert_email}}`. A new risky feature goes into the `docs/runbooks/incident.md` risky-feature table first. |
| B12 | At a security checkpoint (`docs/runbooks/security-levels.md` ①), ask the user to type `/groundwork:security-audit`, then reopen the hardening table. |

- The project CLAUDE.md takes B2 · B5 · B8 · B10 · B12 and the Minor line (+ B11 for a server · API, only B11's second sentence for a user-money front end that is UI; B7 DB with a DB. B1 · B7 live in the ADRs; their rule lines are used only in the umbrella). For a type that scope (section B) leaves B5 out of, drop that line too. Drop the B5 writes line if the UI has no writes sent to a server. With no package manager (infra · contract), drop the first sentence of the B10 line (only the action-pinning sentence stays).
- In umbrella mode a repo's CLAUDE.md drops the B2 · B8 · B10 · B12 lines too. The same lines are in the umbrella CLAUDE.md, which loads alongside in repo sessions (one rule, one place). B11 goes only in a server repo's CLAUDE.md (a user-money front end repo that is UI keeps only the second sentence).
- With P8 off, put in this line (the P8-off line): when writing a second plan, handing off a session for the first time, or closing a plan with deferred items left, read the P8 module with the groundwork:reference skill and ask the user whether to turn it on. A single repo puts it at the end of `{{module_rules}}`; an umbrella, in the umbrella CLAUDE.md 'Shared conventions'.
- With P8, put in the side-branch line and session-start line of `reference/modules/P8.md`. A single repo puts them in `{{module_rules}}`; an umbrella, in the umbrella CLAUDE.md 'Shared conventions' (not in the umbrella's repo CLAUDE.md files).
- If a module other than P8 is on, or it is a native app · webview shell, or the stage 2 auth answer is 'needed', put in this line (the spec-sections line): an L-size spec takes the sections of the modules that are on and that the work touches (for a native app · webview shell its section too, for auth 'needed' the 'Auth — session · permission lifetime' section too), picked from groundwork's spec sections, which you read with the groundwork:reference skill. Risky features go into the runbook table, not the spec. Both a single repo and the umbrella's repos put it at the end of `{{module_rules}}` (not in the umbrella CLAUDE.md, which has a 7.9KB cap).
- If a sentence above already overlaps another line of the template, keep the template's and leave this line out (one rule, one place).
- With no UI, delete the template's 'Design (UI)' line.

### Filling CLAUDE.md (`templates/CLAUDE.md.tmpl`)

| Placeholder | Value |
|---|---|
| `{{project}}` · `{{one_line_purpose}}` · `{{primary_user}}` | Stage 1 summary |
| `{{stack}}` | The stage 2 stack answer |
| `{{client_form}}` | Client form (`n/a` with no UI) |
| `{{profile_line}}` | The rows that are on (e.g. `P1·P3·P5`; `none` if there are none) |
| `{{module_rules}}` | The `## CLAUDE.md rule lines` of the module files that are on, in P order (P8.md's side-branch line · session-start line only for a single repo; the umbrella's repos leave them out because they are in the umbrella CLAUDE.md shared conventions), then at the end section D's P8-off line (if P8 is off; single repo only — the umbrella's repos leave it out because it is in the umbrella CLAUDE.md) and the spec-sections line (the umbrella's repos too). If there is nothing to put in, delete that line |
| `{{docs_rules}}` | The content of `templates/docs-rules.md` as it is. In an umbrella repo's CLAUDE.md, delete that line (the umbrella CLAUDE.md loads alongside) |
| `{{hard_rule_1}}` · `{{hard_rule_2}}` · `{{hard_rule_3}}` | The stage 2 hard-rule answers (if the session changed, the spec section 'Hard rules · operating answers'; with four or more, add lines) |
| `{{boundary_1_path}}` · `{{boundary_1_role}}` · `{{boundary_1_interface}}` · `{{boundary_2_path}}` · `{{boundary_2_role}}` · `{{boundary_3_path}}` · `{{boundary_3_role}}` | The stage 2 module boundary answer |
| `{{cmd_dev}}` · `{{cmd_check}}` · `{{cmd_test_one}}` | The commands actually built in stage 4 (`{{cmd_check}}` is the same value as in `ci.yml`) |
| `{{cmd_verify}}` | With P8, the `verify` built in stage 4 (`pnpm verify` · `make verify`); otherwise delete that line |
| `{{validation_lib}}` | The boundary validation tool (Zod for TS, pydantic for Python, etc.) |
| `{{data_conventions}}` · `{{naming_conventions}}` | Conventions set in the spec · ADRs |
| `{{commit_rule}}` | With P8 off: "Branch only when asked (this line comes before a tool's 'if on the default branch, branch first' instruction). So the final review range starts from the parent of the plan's first task commit (`git log --grep 'Ref: <plan topic>'`), and the branch-finishing menu (merge · PR) is not shown." With P8: "Only plans that change code run in a side branch (the side-branch line below). Docs · research plans and checks run on main." The umbrella's repos write that parenthesis as "(the side-branch line in the umbrella `CLAUDE.md`)" |
| `{{alert_email}}` | The same value as in the section C table. Unless it is a server · API, delete that line (B11) (a user-money front end that is UI keeps only the second sentence) |
| `{{docs_root}}` · `{{context_path}}` · `{{docs_rule_extra}}` · `{{restart_dir}}` | Single-repo · umbrella-repo values are in SKILL.md stage 4 |
| `{{skill_rev}}` | `groundwork@` followed by the `version` field of `<plugin-root>/.claude-plugin/plugin.json` (read it with the Read tool). To carry later fixes into this project, read groundwork's CHANGELOG from this version on |
| `{{docs_language}}` | The language in use when stage 1 was approved (SKILL.md **Language**). The umbrella CLAUDE.md takes the same value |

### Filling the umbrella CLAUDE.md (`templates/CLAUDE.umbrella.md.tmpl`)

| Placeholder | Value |
|---|---|
| `{{project}}` · `{{one_line_purpose}}` · `{{primary_user}}` | Stage 1 summary (`{{project}}` is the umbrella folder name and the prefix of the repo names) |
| `{{unit_1}}` · `{{unit_2}}` | Unit names from the stage 2 deploy-unit answer (`fe` · `be` · `infra` …). With three or more units, add repo map lines |
| `{{unit_1_role}}` · `{{unit_2_role}}` | One line on that unit's role |
| `{{unit_1_stack}}` · `{{unit_2_stack}}` | That repo's stack answer |
| `{{unit_1_gate}}` · `{{unit_2_gate}}` | That repo's one-line gate (the same value as `{{cmd_check}}` in the repo CLAUDE.md). Before the repo exists, the stack's gate (`pnpm check` · `make check`) |
| `{{hard_rule_common}}` | The stage 2 hard rules that span several repos (if the session changed, the spec section 'Hard rules · operating answers'; with two or more, add numbers; with none, delete that line) |
| `{{shared_conventions}}` | Cross-repo conventions set in the spec · ADRs (data formats · naming rules). With none, delete that line |
| `{{docs_rules}}` | The content of `templates/docs-rules.md` as it is |

## E. Shared placeholder rules

- Every `{{…}}` of every template is set by one row of a fill table in this file · `reference/client-forms.md` · `reference/design-interview.md` · the module files that are on (the content slots of `templates/directions.html` take stage 1 copy per the stage 3 rules).
- Placeholders the tables mark "Not asked" and ADR cells with no question are filled from the conversation so far and the stack. If unknown, write `tbd — set in the spec` and settle it in the spec (never leave a blank or a guess). Runbook · `docs/vendors.md` cells filled in stage 4 after the spec is approved take `tbd — set before checkpoint 1`.
- A line · section the template marks "keep this line only in …" (also mid-sentence) · "keep this section only in …" is deleted when it does not apply.
- When done, no `{{` may remain in the documents made: `grep -rn '{{' CLAUDE.md DESIGN.md docs/ .github/workflows/security-watch.yml .claude/settings.json` finds 0 (`${{ … }}` in `ci.yml` is GitHub syntax and out of scope — `security-watch.yml` has none, so a leftover `{{cmd_…}}` is caught before it breaks the workflow).
