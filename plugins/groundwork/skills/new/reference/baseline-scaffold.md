# Baseline scaffold — stage 4 filling · wiring

Details of filling and wiring the items of the `reference/baseline.md` section A table in stage 4.

### Wiring the gate scripts

Not baseline items themselves, but in stage 4 they are tied into the one `{{cmd_check}}` line of B3 · B4. Except for `a11y.spec.ts`, all use only Node 22 and bash · rg, with no external packages. In stage 4 copy **only the files needed** into the new project's `scripts/` (`lib/color.mjs` into `scripts/lib/` — both `.mjs` files import it). Stage 3 (token lock) comes before the copy, so it runs them straight from this skill's `templates/gates/`.

| File (`templates/gates/…` · `templates/design/…`) | What it does |
|---|---|
| `build-tokens.mjs` | UI: `node scripts/build-tokens.mjs design/tokens.json --css design/tokens.css [--ts design/theme.ts]` — generates CSS variables (web) · a theme object (native, colors in hex) from the token source. In `{{cmd_check}}` the same command with `--check` goes before the contrast check — it fails when the generated files differ from the source (hand edits · a missed regeneration). The contrast check reads only the source. Exclude the generated files from the formatter · linter (Biome: `!design/tokens.css` · `!design/theme.ts` in `files.includes`) — if the formatter rewrites them, `--check` always fails |
| `check-contrast.mjs` + `design/contrast-pairs.json` | UI: `node scripts/check-contrast.mjs design/tokens.json design/contrast-pairs.json` — text · background pairs × two themes; fails below the threshold |
| `check-banned.sh` + `banned-patterns.txt` | UI: `bash scripts/check-banned.sh scripts/banned-patterns.txt <source folder>` — rg check for banned patterns (`banned-ok: <reason>` allows one line) |
| `check-docs.sh` | Every project: `bash scripts/check-docs.sh [docs folder]` — spec · plan heads and whether their status matches the checkboxes · the spec of the same name · handoff section 1, the hashes of `done` · ledger `done`, duplicate ledger · ADR numbers, handoff · status board · `CLAUDE.md` · ledger sizes, no `docs/superpowers/`. Vanished hashes and more than 10 closed plans left in `docs/plans/` only warn. A single repo ties this exact command into `{{cmd_check}}` (not as `pnpm docs` — that is a pnpm built-in, so the gate does not run and a browser opens); an umbrella runs it in the 'Umbrella docs hook' below (repos have no `docs/` inside, so it is not tied into the repo gates) |
| `rg-none.sh` | Only for the boundary import check (below), the rg checks of modules (P2 · P8) and the umbrella docs hook: `bash scripts/rg-none.sh <rg args>` — passes only when nothing is found, 1 if something is found, 2 if rg is missing or the folder · pattern is wrong. One command, so it can sit anywhere in an `&&` chain (do not use `! rg` or an exit-code comparison after `;`) |
| `sync-tokens.sh` | Umbrella mode (P6) only: other UI repos copy the source tokens (`scripts/sync-tokens.sh ../<name>-fe/design/tokens.json .`) and check drift with `--check`. SKIP in CI, where the source is absent |
| `a11y.spec.ts` | Web · PWA · webview shell: `pnpm e2e` — axe's WCAG rules and the Tab focus ring. It needs Playwright, so it is not tied into `{{cmd_check}}` and runs in the CI `e2e` job. Install and setup: `reference/client-forms.md` section C |
| `heavy.sh` | P8 only: `scripts/heavy.sh <GB> <command>` heavy-command lock + wait for free memory |
| `trunk.sh` + `lib/trunk/` | P8 only: `bash scripts/trunk.sh [command]` — open · merge · tidy · map side branches. Six commands (`open` · `merge` · `tidy` · `status` · `map` · `help`; called with no argument it prints a short map), copied into `scripts/` together with `lib/trunk/`. An umbrella uses the umbrella `scripts/`. Not wrapped in `heavy.sh`. Rules: the runbook `docs/runbooks/trunk.md` |

**Boundary import check** (projects whose code is split along folder boundaries, except infra · contract). Lint · types · tests do not catch the rules of `CLAUDE.md` 'Structure and boundaries', so tie them into `{{cmd_check}}` with `rg-none.sh`. Per boundary, keep only what applies. Examples (adjust to the stack):
- A library allowed in one folder only (a P7 SDK, etc.) imported outside it: `bash scripts/rg-none.sh -n '(from |import[ (]|require[(]).@?stripe' src --glob '!**/adapters/stripe/**'` (Python changes only the pattern: `'^\s*(from|import) +stripe\b'`)
- A boundary's inner implementation imported from outside (the interface is the boundary's index): `bash scripts/rg-none.sh -n 'from .(@/|[.]+/)+billing/' src --glob '!**/billing/**'` (Python changes only the pattern: `'^\s*(from|import) +myapp[.]billing[.]'`)

A wrong pattern finds nothing and just passes. So once it is wired in, add one violating import, watch the gate fail and revert it. Test folders are not checked (some tests, like rule tests, use the SDK directly).

**`.worktrees/` probe** (stage 4 step 9). Side branch worktrees sit inside the root, so check that excluding `.worktrees/` from the tool configs really works. If the config is wrong, stale copies in side branches break or slow the gate. Put files that would fail types · lint · tests in `.worktrees/probe/`, see that the gate still passes, then delete them (the same shape as the boundary import check above).

Without a UI, the token · contrast · ban check files are not copied. Other locations: `gitleaks.toml` → root `.gitleaks.toml` (gitleaks reads it from the repository root automatically), `ci.yml` → `.github/workflows/ci.yml`, `secrets.yml` → `.github/workflows/secrets.yml`, `contrast-pairs.json` → `design/` (at the stage 3 lock), `a11y.spec.ts` → `e2e/`.

### Secret-value hook (every project, B2)

The hook scans staged changes with `gitleaks git --pre-commit --staged --redact` and blocks the commit if gitleaks is missing. In stage 4, in order:

1. Check `command -v gitleaks`. If it is missing, ask the user to install it (macOS `brew install gitleaks`) and turn the hook on once it is installed.
2. Copy `templates/gates/pre-commit` to `.githooks/pre-commit`. If shell `cp` is blocked and you move it with Read · Write, the execute bit is lost.
3. **Right after copying, separately from the install script**, run directly in the shell: `chmod +x .githooks/pre-commit && git config core.hooksPath .githooks`. git skips hooks without the execute bit, and the bit is recorded in the commit, so do it before the first commit (checks start from the skeleton commit, and clones get an executable hook).
4. Re-wiring for new clones: pnpm puts `"prepare": "git config core.hooksPath .githooks || true"` in `package.json`, uv the same command in the Makefile `install` target, anything else (infra · contract) a Makefile `hooks` target or a README install line. This does not replace 3 (a `pnpm install` that already ran does not run a `prepare` added later).
5. Along with the gate output of SKILL.md stage 4 step 9, show the output of `git config core.hooksPath` (value `.githooks`) and `test -x .githooks/pre-commit && echo hook-executable`. If they differ, redo 3.

`.gitleaks.toml` · the hook · `ci.yml` · `secrets.yml` go into the one commit `ci: add required checks and secret scanning`.

### Config module (every project, B2)

env is read in this one module only. The builder writes it for the stack and commits it with `chore: bootstrap project skeleton`. On top of schema validation:

- **Test guard:** when started for tests · e2e, it starts only if the DB · RPC · external API addresses are local (`localhost` · a test container · a temp folder or in-memory DB), and refuses to start otherwise. Scheduled jobs · workers are not registered in tests (with P2, test processes get no worker · scheduler `ROLE`, and job tests call the job function directly). A deployed worker can pick up a job a test made in a shared environment and really send it. Test mode is turned on by the runner config (pytest · vitest config, Playwright `webServer.env`), not by an env file — the dev server reads env files too. 1 test: given a non-local DB address in test mode (for a file DB, a path outside the temp folder), startup is refused.
- **Server-only values (web with a server):** split a server-only schema from a public schema, and mark the module that reads the server schema `server-only` so importing it from the client fails the build. Values sent to the browser are public, down to props passed by server components · values injected at run time. Calls that need a key go through a server route and return only the result.
- **Run-time values (web with a build):** public-schema values injected at deploy time are not read in pages frozen at build time (static generation · prerender) but through routes rendered per request or a runtime config endpoint. The endpoint serves only public-schema values — server-only values stay on the server per the line above. 1 test (e2e): build with that value empty, start with the value given, and the page shows it.

### Umbrella docs hook (umbrella mode)

The umbrella's docs-only git has no CI, so the secret-value scan and the docs gate run in the commit hook (the secret rotation · incident runbooks live in the umbrella). In umbrella scaffold step 1, before the first commit, in order:

1. Copy `templates/gates/check-docs.sh` · `rg-none.sh` into the umbrella `scripts/` and `templates/gates/pre-commit-umbrella` to `.githooks/pre-commit`. The hook blocks commits when gitleaks is missing, so check first as in 'Secret-value hook' step 1. Also make the umbrella root `.claude/settings.json` from `templates/claude-settings.json` — Claude Code reads only the settings of the folder the session was opened in, so a session opened at the root (`/groundwork:new` · the P8 controller) does not get the repos' deny lists. Its `{{claude_deny}}` is the repos' values combined ('Filling the Claude settings').
2. Right after copying, wire and check in one shell command: `chmod +x .githooks/pre-commit && git config core.hooksPath .githooks && test -x .githooks/pre-commit && echo hook-executable`.
3. Commit it all together in `chore: bootstrap umbrella docs`.
4. Show the output of `git config core.hooksPath` (value `.githooks`) and `test -x .githooks/pre-commit && echo hook-executable`. If they differ, redo 2.

### Filling the secret rotation runbook (`templates/docs/runbook-secret-rotation.md`)

| Placeholder | Value |
|---|---|
| `{{environments}}` | The answer to `reference/baseline.md` section C item 1 |
| `{{rotation_interval}}` | Recommended: 90 days (the provider's expiry cycle if that is shorter) |
| `{{secret_store}}` | The secret store picked with the stage 2 runtime · deploy target (e.g. the deploy platform's secret settings) |
| `{{reload_method}}` | From the deploy target: how the app picks up the new value (e.g. redeploy, service restart) |
| `{{verification_command_or_page}}` | From stage 4: a command or screen that really calls one feature using that key (not the health check, which uses no key) |

### Filling the Claude settings (`templates/claude-settings.json`)

This is the `.claude/settings.json` of stage 4 step 4. `permissions.deny` is the list Claude Code blocks when an agent calls something a person should do (prod deploys · writing secrets · applying to the prod DB · releases) — written hard rules get forgotten in a hurry. The template's fixed rules (`gh secret set` · `gh release create` and those named below) stay as they are in every project; only the per-deploy-target rules go in the slot below. Umbrella mode puts it at the umbrella root too ('Umbrella docs hook' step 1): its `{{claude_deny}}` is the repos' rules combined.

| Placeholder | Value |
|---|---|
| `{{claude_deny}}` | Deny rules picked from the stage 2 deploy target and the ADR `release-model` answers. Replace this element, quotes included, with several `"Bash(<command prefix>:*)"` elements, or delete it when there is nothing to put in (a CLI · library that does not deploy). The prefix goes only as far as the subcommand, with no flags — a changed flag order slips past it (`vercel deploy --prebuilt --prod`). Forms called through a package runner (`npx` · `pnpm exec` · `pnpm dlx`) get a line each too. What goes in: prod deploys · service updates (e.g. `Bash(fly deploy:*)` · `Bash(flyctl deploy:*)` · `Bash(vercel deploy:*)` · `Bash(vercel --prod:*)` · `Bash(vercel --prebuilt:*)` · `Bash(vercel promote:*)`) · platform secret writes (e.g. `Bash(fly secrets set:*)` · `Bash(vercel env add:*)` · `Bash(wrangler secret put:*)` · `Bash(npx wrangler secret put:*)`) · prod DB applies (for Supabase the raw CLI `Bash(supabase db push:*)` · `Bash(pnpm exec supabase db push:*)` · `Bash(npx supabase db push:*)` — the staging apply is `pnpm db:push`, so it is not caught; if there is no staging and `db:push` reaches prod, also `Bash(pnpm db:push:*)` · `Bash(make db-push:*)`) · for a native app, store · OTA publishing (`Bash(pnpm exec eas submit:*)` · `Bash(pnpm exec eas update:*)`) |

- Not put in: what the project settings already carry from the template — `deny` for `terraform apply` · `terraform destroy` · `supabase db reset` · `.env.production*` reads, and `ask` for `git push` — and prefixes that would block commands stage 4 · the gates call (the one-line gate · `verify` · staging `db:push` · `supabase help db push`, which a DB migration calls to settle its target).
- Check: in stage 4 step 9, call one rule with `--help` added (e.g. `gh secret set --help`) and show the user it is denied (if it is not blocked, only the help prints). Umbrella mode checks the root settings from a root session. If it is not denied (the settings were not read yet), note it in the report and check again next session.

### Filling the incident runbook and hardening table (`templates/docs/runbook-incident.md` · `templates/docs/security-levels.md`)

| Placeholder | Value |
|---|---|
| `{{status_notice_channel}}` | How users are notified (status page · in-app notice · mail). If unknown, `tbd — set before checkpoint 1` |
| `{{risk_table_rows}}` | The rows of the spec section 'Security — risky-feature table' as they are. If the spec has no such table, one row with only `tbd — listed here before the first risky feature` in the feature cell. Types whose section 0 is deleted leave it unfilled |
| `{{restore_steps}}` | The restore order from the backup method in the stage 2 data · storage answer. If unknown, `tbd — set before checkpoint 1` |
| `{{cloud_audit_alert_steps}}` | The steps that turn on audit-log alerts, found in stage 4 from the deploy platform's docs (B11 "signal 4" below). If the platform's built-in features cannot do it, write `not possible — hardening table` and add a line to ②. Types whose `(signal 4)` lines are deleted leave it unfilled |
| `{{audit_money_threshold}}` | The amount in P9 answer 2 (the entrusted-money level that calls for an external audit). If item 2 was not asked (no operator key) or the answer has no amount, `tbd — set before checkpoint 1`. With P9 off that line is deleted, so it is not filled |

- The runbook keeps sections per type: server · API all of them (C only with P9 on, E only with a user-money web front end) · UI · CLI · library B · End · Log (a UI that is a user-money front end also 0 · C, on the web also E) · infra · contract A · B (C too with P9) · End · Log. The hardening table deletes from ② · ③ · the account table the lines whose tag (the parenthesis at the very start of the line) names something that is off — `(alert function)` · `(signal 4)` are deleted by types whose B11 cell in `reference/baseline.md` section B lacks them, `(deploy)` by types with an empty B7 cell (a CLI · library that does not deploy), `(daily watch)` by projects with no `security-watch.yml` (infra · contract with no package manager). Phrase tags in ① delete only that phrase.
- Copy the two files to `docs/runbooks/incident.md` · `docs/runbooks/security-levels.md` in one commit `docs: add incident and security-level runbooks` (with a release runbook, include it: `docs: add incident, security-level and release runbooks`). Umbrella mode keeps a single set in the umbrella `docs/runbooks/` (sections · lines kept as the union over the repo kinds) and commits it in the umbrella git.
- In the **stage 4 end report**, include the ③ "Now" list of `docs/runbooks/security-levels.md`.

### Filling the release runbook (`templates/docs/runbook-release.md`)

Types with an empty B7 cell (a CLI · library that does not deploy) do not get it. No new questions.

| Placeholder | Value |
|---|---|
| `{{tag_deploy}}` · `{{deploy_order}}` | The same cells of ADR `release-model` as they are |
| `{{rollback_method}}` | The command or screen, found in stage 4 from the deploy target's docs, that rolls back to the previous release (the same image digest · revision) (re-running the previous release's deploy also counts). For a deploy that cannot be rolled back (contracts, etc.), `cannot roll back — ` followed by what to do instead. If unknown, `tbd — set before checkpoint 1` |

The query commands of the daily check (section 8) are found in stage 4 from the deploy platform's docs and written into the table. If unknown, leave `tbd — set before checkpoint 1` (the `tbd` check of ③ "before checkpoint 1" catches it).

### Filling `ci.yml`

| Placeholder | pnpm (Node) | uv (Python) |
|---|---|---|
| `{{cmd_install}}` | `npm i -g pnpm@<exact version> && pnpm install --frozen-lockfile` (the `package.json` `packageManager` version as is, 10.26 or later — "Supply-chain settings" below. Do not rely on the runner's corepack) | `pipx install uv==<exact version> && uv sync --frozen` (the `uv --version` used in stage 4, 0.9.25 or later) |
| `{{cmd_check}}` | The one-line gate `pnpm check` (the same command as in CLAUDE.md) | The one-line gate `make check` (the same command as in CLAUDE.md) |
| `{{cmd_audit}}` | `pnpm audit --audit-level high` | `uv run pip-audit` (dev dependency) |
| `{{cmd_deadcode}}` | `pnpm knip` (dev dependency) | `uv run vulture <source folder>` (dev dependency) |

- If a value contains `: ` or `#`, quote it (bare, it breaks the YAML).
- The one-line gate's typecheck also covers `scripts/` · `tests/`, which the build does not see, and its lint is the read-only variant (no `--write` · `--fix` editing files). CI runs without `.env*`, so local e2e runs with the same fail-fast env too (backend · external addresses pointed somewhere unreachable) — local green is not CI green.
- The runner image is a pinned version (`ubuntu-24.04`), not `ubuntu-latest`. When `-latest` moves, tool installs get refused and CI turns red overnight. To upgrade, change the `runs-on` of all three workflows in one commit and watch the first run. When the image retires it fails loudly (better than a silent move).
- If the gate uses `rg` (the UI's `check-banned.sh`, `rg-none.sh` for boundaries · modules), GitHub's Ubuntu runner has no ripgrep, so uncomment the ripgrep install step of the `check` job (only the `check` job uses rg). Do not prepend the install command to `{{cmd_check}}` — it is the exact command of the local gate.
- Check locally too: if `bash -c 'command -v rg'` prints nothing in a plain shell (rg inside Claude Code is a shell function, invisible to scripts and `make` · `pnpm`), ask the user to install ripgrep (macOS `brew install ripgrep`). Until it is installed, gates with rg checks fail.
- For infra · contract, B4 is format · validate jobs only: `{{cmd_install}}` = installing that tool (the official install method, version pinned), `{{cmd_check}}` = format check + validate (e.g. `terraform fmt -check -recursive && terraform init -backend=false && terraform validate`, `forge fmt --check && forge build`). Without the tools, delete the `audit` · `deadcode` jobs.
- If the project must pin its Node version (`engines` · `.nvmrc`), add `actions/setup-node` before the `{{cmd_install}}` step (pinned with a commit SHA and a `# v<version>` comment — the same value as the line in the `ci.yml` `eas-build` job, with `node-version-file`). Otherwise the runner's installed Node is used.
- For a native app · webview shell, uncomment the `eas-build` job and replace the `npm ci` in it with the `{{cmd_install}}` value. The job runs only on manual dispatch (`workflow_dispatch`) — it builds both platforms at once, so running it on every push uses up the monthly EAS build quota in days. `eas-cli` is an exact-version devDependency — CI does not fetch it separately, and it goes through the lockfile · the 3-day hold. If the available versions trip the `audit` job's audit or the 3-day hold, leave `eas-cli` out and keep the job commented, with the reason and 'uncomment when a passing version is out' in the comment above the job. No audit · 3-day-hold exceptions even for dev tools. The user puts the `EXPO_TOKEN` secret in the repository settings.
- For web · PWA · webview shell, uncomment the `e2e` job and replace the `npm ci` in it with the `{{cmd_install}}` value. The browser is fetched per the lockfile's Playwright version. On a stack without `pnpm`, also replace the two lines after it with that stack's Node install and Playwright run.

### Supply-chain settings (B10)

| Tool | File | Setting |
|---|---|---|
| pnpm | `pnpm-workspace.yaml` (even with a single package) | `minimumReleaseAge: 4320` (3 days after publishing) · under `allowBuilds:`, `<name>: true` or `false`, with a reason comment per line |
| pnpm | `package.json` | `"packageManager": "pnpm@<exact version>"`, 10.26 or later (lower, and the settings above are silently ignored) |
| uv | `pyproject.toml` `[tool.uv]` | `exclude-newer = "3 days"`, uv 0.9.25 or later (below 0.9.17 it cannot parse this value, below 0.9.25 the `= false` of the exception below) |
| CI actions | `.github/workflows/*.yml` | Every `uses:` is a 40-character commit SHA + a `# v<version>` comment (never a tag alone). Container base images use an `@sha256:` digest |
| Docker | `Dockerfile` · `.github/dependabot.yml` | `FROM` is `<image>:<tag>@sha256:<digest>` (with a tag alone you never notice when updates to that tag quietly stop). Updates come as PRs opened by `package-ecosystem: "docker"` · `interval: "weekly"` · `cooldown: default-days: 3` in `dependabot.yml` — Dependabot alerts do not look at images. Dependabot can fix only the first `FROM`, so with several stages align the rest in that PR |
| Web fonts | The framework's font config | Keep the font files in the repo and load them locally (e.g. Next.js: `next/font/local` instead of `next/font/google`). If the build fetches remote fonts, it breaks when the remote is slow or blocked |

- **Set these before the first install.** Run generators with the option that skips installing (`create-next-app --skip-install` · `create-expo-app --no-install`), create the config files, then install. If it is already installed, delete the lockfile and `node_modules` and reinstall.
- **If install fails because of the hold, do not turn the setting off.** Pin the newest version published more than 3 days ago (the only exception is an urgent security patch, as below).
- **On `ERR_PNPM_IGNORED_BUILDS`**, check whether that package really needs its build (native binaries, etc.) and set true/false in `allowBuilds`. If unsure, set false and watch the gate. Never use `dangerouslyAllowAllBuilds`.
- **The only exception is an urgent security patch:** pnpm `minimumReleaseAgeExclude: ["<name>@<version>"]` · uv `exclude-newer-package = { <name> = false }` + pin the dependency as `<name>==<version>`, both with a removal-date comment. Delete both after 3 days. Procedure: `docs/runbooks/incident.md` B-1.
- **Daily watch** (`security-watch.yml`): 20:37 UTC + manual runs (it avoids the top of the hour, when GitHub delays or drops scheduled runs). On failure GitHub sends a workflow failure mail. The recipient is whoever last edited the cron line, and a public repo's schedule turns off after 60 days without activity → check both in `docs/runbooks/security-levels.md` ③. The `audit` job of `ci.yml` (on push) stays as it is.
- **Commits:** the config files go in `chore: bootstrap project skeleton`, the workflow in `ci: add the daily security watch`.

### DB migrations (B7, projects with a DB)

The schema changes only through SQL migration files. Put the three things below in the scaffold and commit them with `chore: bootstrap project skeleton`.

- **Folder:** one standard location of the tool (Supabase: `supabase/migrations/`, new files with `supabase migration new <name>`). Applied files are never edited; add a new file.
- **One apply command:** `pnpm db:push` (uv: `make db-push`) applies the migrations, then generates types.
  - No generation if the apply fails (`&&`). Generation writes to a temp file and moves it on success. Writing straight with `>`, a failed generation empties the types file.
  - Generated files are committed and never edited by hand.
  - It needs a live DB, so it is not tied into the one-line gate.
  - The targets are dev · staging. Prod follows the deploy order of ADR `release-model`.
  - It runs only in the main checkout. Put `[ "$(git branch --show-current)" = main ] || { echo 'db:push runs only in the main checkout — docs/runbooks/trunk.md 3'; exit 1; }` first (uv: the first line of the `db-push` target, with `$` as `$$`). Applying to the shared DB from a side branch puts the migration history out of step with main.
- **One verify command:** `pnpm verify:db` (uv: `make verify-db`) checks against the real DB (staging) that constraints · triggers · unique indexes really reject bad input. It inserts violating rows inside a transaction, confirms the rejection by SQLSTATE (unique violation `23505`, foreign key `23503`, check constraint `23514`) and rolls back. Make it in the scaffold even with no constraints yet: with an empty check list it reports `0 checks` and exits, and the migration task that creates a constraint adds its check. It needs a live DB, so it is not tied into the one-line gate; run it after migrations that change constraints. Never run it against prod.
- **Supabase example (v3.0, staging):** `"db:push": "supabase db push --yes --remote=<staging ref> && supabase gen types --remote=<staging ref> > <types file>.tmp && mv <types file>.tmp <types file>"`.
  - Never omit the target: settle it with the installed CLI's `supabase help db push` and write it out (forms starting with `db push` are blocked by the Claude settings). The default target differs by version: v2.109 defaults to the linked project with `--linked` · `--local`; v3.0 defaults to local with `--remote`.
  - v3.0 stops commands that change a hosted project (`db push`, etc.) with `HostedMutationConsentRequiredError` instead of asking when there is no terminal or an AI agent runs them (nothing changes; `echo y |` does not get through either). The staging script does not rely on the linked project; it pins the target with `--yes --remote=<staging ref>` on `db push` and `--remote=<staging ref>` on `gen types`. Commands that reach prod get no `--yes`. With no staging (prod only), `db:push` reaches prod, so it gets no `--yes`.
  - **If the ref is not known yet** (no staging project yet, etc.), do not drop `db:push`, and do not stop the scaffold to ask for the ref either. Move the command into `scripts/db-push.sh` (`set -euo pipefail`) and take the ref from an environment variable: `ref="${SUPABASE_STAGING_REF:?pass the staging ref as SUPABASE_STAGING_REF}"` (prod only: `SUPABASE_PROD_REF`, without `--yes`). With the value empty it stops without changing anything. Write in the report 'once the staging ref is set, pass it as `SUPABASE_STAGING_REF`'.
  - Do not query the account to find the ref. Commands that need the account token, such as `supabase projects list` · `link`, pop up the user's keychain prompt, and `login` opens a browser.
  - The CLI is an exact-version devDependency (B10). If the version fetches its binary through an install script, add it to the allowlist. v3.0 ships the binary as an optional dependency, so it is not added.

### Alerts and audit log (B11)

- **One mail address receives everything:** `{{alert_email}}` (the answer to `reference/baseline.md` section C item 3). Every security alert · 5xx · job failure · daily watch failure comes here.
- **Send only what needs a person to act.** Informational records stay in logs. The subject starts with `[severity][project][signal]` so the morning order can be set from subjects alone, and the first body line gives the runbook section path from the table below (e.g. `docs/runbooks/incident.md A`).

| # | Signal | Source | Mail | Runbook section |
|---|---|---|---|---|
| 1 | Daily dependency watch failure (only projects with the watch) | GitHub (`security-watch.yml`) | On every failure | B |
| 2 | Admin · permission actions: granting · revoking roles, creating keys · tokens, admin actions that move money, security setting changes | App audit log | Per event (if they pile up, a digest mail via the hardening table) | A |
| 3 | Auth anomalies: a spike in failed logins, an admin account logging in from a new device · location | The app or the auth provider's feature | When over the threshold | A |
| 4 | Cloud · platform audit: permission · role changes, new access keys, deploys from outside CI, direct server · container access, root · owner logins | The deploy platform's audit-log alert feature | Per event | A |
| 5 | 5xx · job failures | B6 | When over the threshold | 0 |
| 6 | Money-flow anomalies: nearing · exceeding limits, a sudden balance drop, attempts to send to unregistered addresses, (with user-money actions) a spike of withdrawals · sells by many users in a short time | P9 | Per event | C |
| 7 | External-script anomalies: never-seen hosts among CSP violation reports (user-money web front ends only) | The app's CSP report endpoint | Per new host (batched) | E |
| 8 | Monthly budget: cloud · CI spend nearing the set budget (projects using cloud or paid CI) | The platform's budget alert | When over the threshold | None — find the cause on the spend screen (big services · scaling limits · CI minutes) and decide whether to cut or raise |

- **Route:** signals from the app (2 · 3 · 5 · 6 · 7) go straight out through one mail-sending service. Pick it in stage 4; recommended is SES if you already use AWS, otherwise Resend (at alert volume Resend stays within its free plan and SES costs next to nothing — check prices on the official pages when picking). Signals 1 · 4 · 8 are mails the platforms send.
- The alert function sits behind one P7-style adapter layer (switching the sending service leaves app code unchanged).
- **Batching:** the same signal within a set window of a few minutes is batched into one mail (count and first · last time in the body). Because if alerts pile up during an attack and hit the daily send limit, the alerts that matter get blocked.
- The sending key follows the B2 secret rules and `docs/runbooks/secret-rotation.md`. The sending service account goes in the non-cloud admin account table of `docs/runbooks/security-levels.md` ③, and with P7 on, one line in `docs/vendors.md` too.
- **Signal 4:** `/groundwork:new` does not handle live cloud credentials. In stage 4 find the steps that turn on audit-log alerts in that platform's docs and write them as a task for a person into `{{cloud_audit_alert_steps}}` under ③ "Now" of `security-levels.md`. With an infra repo (IaC), put the alert settings in code. If the platform's built-in features cannot do it, write "not possible — hardening table" and add a line to ②.
- Signal 6 for a contract-only project with P9 on follows the `reference/modules/P9.md` scaffold.
- **App audit log:** one append-only store (a table or a stream), one line per admin action (who · what · target · before/after · request id · time). The app's normal permissions cannot delete or edit it.
- **Scaffold (server · API):** one alert-sending function (enforces the subject format, recipient from the config module's `ALERT_EMAIL`) · one audit-log write function · two tests — ① calling one admin action produces one audit-log line and one alert (mail sending is a fake) ② calling the same signal several times within the window sends once with the right count. Commit `feat: add audit log and alert sender`.
- **Live check (a person):** at the end of stage 4, really send 1 test mail through the alert function and confirm it arrived on the phone.

## Output map

```
CLAUDE.md  CONTEXT.md(## Project profile)  DESIGN.md(UI)
docs/adr/NNNN-*.md   docs/specs/YYYY-MM-DD-<topic>-design.md   docs/plans/YYYY-MM-DD-<topic>.md   docs/runbooks/
docs/design/directions.html(UI)   design/tokens.json → tokens.css|theme.ts, contrast-pairs.json(UI)
scripts/(gates)   .github/workflows/*.yml   .gitleaks.toml   .githooks/pre-commit   .claude/settings.json
src|app/<folder per boundary>/   tests/   .gitignore   .worktrees/(ignored)   .env.example   package.json|pyproject.toml   biome.json|ruff config
(P7) docs/vendors.md   (P8) docs/ledger.md docs/plans/handoff.md docs/plans/status.md docs/runbooks/trunk.md scripts/heavy.sh scripts/trunk.sh   (native) app.config.ts eas.json
```

Umbrella mode:
```
<name>/            ← docs-only git (.gitignore: <name>-*/)
  CLAUDE.md(umbrella: repo map · docs rules)  CONTEXT.md  scripts/  .githooks/  docs/{specs,plans,adr,design}/  .worktrees/(ignored)  (DESIGN.md · directions.html in docs/design/)
  <name>-fe/       ← its own git: CLAUDE.md(gitignored) design/tokens.json src/ tests/ …
  <name>-be/       ← its own git: CLAUDE.md(gitignored) src/ tests/ …
```
