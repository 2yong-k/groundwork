# Overlay — putting the `/groundwork:new` shape onto a project that is already running

`SKILL.md` stage 0 step 2 sends you to this file. Follow this file instead of the stage 0 table and stages 1–4. No discovery interview · design interview. An overlaid project ends up in the same shape as one started with `/groundwork:new` from the beginning. Typing `/groundwork:new` again in the same folder then goes to a normal resume (stage 0 ①–④).

- Where things overlap, the `/groundwork:new` shape wins. What `/groundwork:new` does not have stays as it is. Nothing is deleted.
- Gates are turned on at once. Existing violations are not fixed in one go but tied into the violation baseline (section H). The violation baseline only shrinks, and shrinking it is outside the overlay plan.
- Flow: analysis (B, read-only) → analysis message (C) or stop (D) → approval → module message · plan draft (F · G) → plan approval → execution (G · H · I) → end report (J).
- The four principles hold. No files before the analysis message is approved. One question per message. No push · rebase · force.

## A. When

Stage 0 step 2 sends you here in two cases.

1. **An open overlay plan.** If `docs/plans/????-??-??-overlay.md` has a status other than `done` · `dropped` · `superseded`, start from that plan: `draft` → from the approval question of section F step 3, `approved` → from execution, `active` → from that plan's `Resume at`. The first message the user sees starts with the stage 0 five-line report, with the plan path and `Resume at` in `Next step`. Do not look at the stage 0 table. The missing stage 4 pieces are filled by the plan's T3, so do not drift into "Resume 4". An overlay plan is a plan whose H1 holds `overlay plan` (section G). If the H1 lacks those words, it is another plan that only shares the name, so check case 2; if that does not apply either, leave this file and go to stage 0 steps 3 · 4.
2. **An existing project with no profile table.** There are already several source files (`src/` · `app/` · package folders · Go modules · sub-repos, anywhere) but `CONTEXT.md` has no `## Project profile`. Start at section B. `/groundwork:new` writes the profile table in stage 2 and makes source in stage 4, so source without a profile table means a project `/groundwork:new` did not start. Except: if among the folders above cwd there is a nearest one whose `CLAUDE.md` has `## Repo map` (not only the parent; it also covers a side branch worktree `<umbrella>/.worktrees/<name>/<repo>`) and cwd is a repo of that map, it is not an overlay (the profile table is in the umbrella). Tell the user to type `/groundwork:new` in the umbrella folder, and stop without creating files.

**Umbrella test.** It is an umbrella if cwd's `CLAUDE.md` has `## Repo map`, or every subfolder (other than docs · tool folders such as `docs/` · `scripts/`) has a `.git`. An umbrella falls under case 2 when even one of its repo folders has source. Without `## Repo map`, estimate the repo names · roles in the analysis and put them in the analysis message (section I). An umbrella's overlay plan · profile table go in the umbrella `docs/` · `CONTEXT.md`.

## B. Analysis (read-only)

This section writes no files. It is done with one run of the shell below and the file reads it needs (manifests · lint config · `CLAUDE.md` · open plans · `.env.example` · workflows). Nothing appears except ignored install folders (`node_modules` · `.venv`) and tool caches.

### 1. State collection shell

It prints one block for cwd and for each subfolder with a `.git` (repo). A single repo gives the one block `== .`.

```bash
{ echo .; find . -mindepth 2 -maxdepth 2 -name .git | sed 's#/\.git$##' | sort; } | while IFS= read -r r; do
  echo "== $r git=$([ -e "$r/.git" ] && echo yes || echo no) changed=$(git -C "$r" status --short --untracked-files=no 2>/dev/null | wc -l | tr -d ' ') untracked=$(git -C "$r" status --short 2>/dev/null | sed -n 's#^?? ##p' | while IFS= read -r u; do [ -e "$r/${u}.git" ] || echo "$u"; done | wc -l | tr -d ' ') src=$(git -C "$r" ls-files 2>/dev/null | grep -cE '\.(ts|tsx|js|jsx|mjs|py|go|rs|sol|java|kt|swift|rb)$') commits=$(git -C "$r" rev-list --count HEAD 2>/dev/null) authors=$(git -C "$r" log --format=%ae 2>/dev/null | sort -u | wc -l | tr -d ' ') first=$(git -C "$r" log --reverse --format=%cs 2>/dev/null | head -1) hooksPath=$(git -C "$r" config core.hooksPath 2>/dev/null)"
  ls -A "$r" | grep -E '^(package\.json|pnpm-lock\.yaml|package-lock\.json|yarn\.lock|pyproject\.toml|uv\.lock|requirements.*\.txt|go\.mod|Cargo\.toml|foundry\.toml|Makefile|\.eslintrc.*|eslint\.config\..*|\.prettierrc.*|prettier\.config\..*|biome\.jsonc?|\.flake8|setup\.cfg|tox\.ini|\.husky|lefthook\.ya?ml|\.pre-commit-config\.yaml|\.githooks|\.gitleaks\.toml|\.claude|\.env\.example|CLAUDE\.md|CONTEXT\.md|DESIGN\.md)$' | tr '\n' ' '; echo
  grep -E '^\[tool\.(black|ruff|isort)' "$r/pyproject.toml" 2>/dev/null
  find "$r/.github/workflows" -name '*.y*ml' -exec awk '/^jobs:/{j=1;next} /^[^ #]/{j=0} j && /^  [A-Za-z0-9_-]+:/{print FILENAME, $1}' {} + 2>/dev/null
  [ -f "$r/CLAUDE.md" ] && wc -c < "$r/CLAUDE.md" && grep -E '^#{1,3} ' "$r/CLAUDE.md"
done
find docs -type f 2>/dev/null | sort | head -100; grep -rEm2 '^>? ?(Status|Resume at):' docs 2>/dev/null; grep -n '^## Repo map' CLAUDE.md 2>/dev/null
```

- `changed` is the count of unsaved changes to tracked files, `untracked` the count of untracked lines (`??`) (repo folder lines visible in the umbrella do not count). `src` is the count of tracked source files. `commits` · `authors` · `first` (first commit date) are P8 signals (section E).
- Per repo it prints the manifests, lint · format config (`.eslintrc*` · `eslint.config.*` · `.prettierrc*` · `biome.json` · `[tool.black|ruff|isort]` in `pyproject.toml` · `.flake8`), hook tools (`.husky/` · `lefthook.yml` · `.pre-commit-config.yaml` · `core.hooksPath`), workflow job names, `CLAUDE.md` size · headings. At the end it prints the `docs/` file list, the spec · plan heads and `## Repo map`.
- Dependency names · environment variable names come from reading the manifests and `.env.example` (section E).

### 2. Tests

- First sort out the repos to skip (section I). For each repo in scope, run that repo's test command (the `test` script of `package.json` · the `test` target of the `Makefile` · `pytest` · `python3 -m unittest` · `go test ./...`). Skipped repos' tests are not run.
- If no install is needed (no dependencies · already installed), run the tests right away. If an install is needed, use only installs that respect the lockfile (`pnpm install --frozen-lockfile` · `uv sync --frozen`). If an install is needed but there is no lockfile or that install fails, do not run the tests; write that and why in the analysis. With no tests, write 'no tests'.
- Compare `git status --short --untracked-files=no` per repo before and after the install · tests. A changed tracked file is a stop reason (section D 1). New, non-ignored folders (caches such as `__pycache__/` · `.pytest_cache/` · `coverage/`) are not a stop reason; write them in the analysis as a T1 `.gitignore` task.

### 3. Secret scan

- For every git (the umbrella and all repos), history included: `gitleaks git --redact --verbose <folder>`. `--verbose` prints the file · commit · rule of each find.
- Sort each find into a real secret or a false positive. A false positive is one whose value is visibly fake in the file (test fixtures · examples · placeholder values in docs). Everything else counts as a real secret.
- Never copy secret values into messages. Write only the file · commit · rule names.
- If gitleaks is missing, point to installing it as in stage 4 (macOS `brew install gitleaks`) and stop (section D 4).

### 4. Violations per gate

- For each gate `/groundwork:new` will turn on (those of lint · type check · `check-banned` · `rg-none` · `check-docs` · contrast · a11y that apply to this project), count the files with violations. That is the amount that will go into the violation baseline.
- Count only when the template tool can run without changing tracked files or config — that is, when the tool is already there and runs read-only (e.g. `biome ci .` · `ruff check --no-cache .`; `check-docs.sh` straight from this skill's `templates/gates/`).
- If the tool must be fetched or a config file created, do not count; write "counted in plan ②".

## C. Analysis message shape

Show the analysis in one message. Items come in exactly the order below.

```
Overlay analysis. No files have been created yet.

Target: single repo / umbrella (N repos, umbrella git yes · no)
Repos: <folder> = <stack> · N source files · N tests passing · 0 unsaved changes / …
Repo map (estimated, only when the umbrella has no map): <folder> = <role> / …

Project profile (estimated)
| Row | yes/no | Reason | Reason path |
|---|---|---|---|
| P1 Numbers and units | yes | payment SDK · amount column | `package.json` · `src/db/schema.ts` |
| P2 Multiple instances · async | no | no signal | |
| … 9 rows through P9 | | | |

Overlaps
| /groundwork:new shape | Now | Action |
|---|---|---|
| `CLAUDE.md` | 9 rule lines · 4 Mistakes log lines | merge (rewrite in the template shape and move the rules) |
| spec · plan location | `docs/superpowers/` | move (`docs/specs` · `docs/plans`) |
| lint · format | eslint · prettier | replace (Biome) |
| … | | |
Rules that cannot move when the lint tool changes: …

Kept because /groundwork:new lacks them: deploy job (`.github/workflows/deploy.yml`) · …
Skipped: <folder> — archive / stack with no template (<stack>)
Existing violations per gate (to go into the violation baseline): lint N files · type check N files · check-docs counted in plan ② · …
Secret scan: no real secrets · N false positives (allowlist candidates: `<path>` …)

Shall I make the overlay plan with this scope · profile?
```

- The P1–P9 table is the `reference/profile.md` C shape plus a reason-path column. Write all nine rows. The reason is the section E code signal; the reason path is the file · folder where that signal is. The rows that are on set the gate · module scope, so get them confirmed together with the scope.
- The overlaps table has one row per target of the section G moving-rules table. The columns are `/groundwork:new shape | Now | Action`, and the action is one of move · merge · create · replace · skip.
- When the lint tool changes, attach a list of the existing config's rules the new tool cannot express.
- If an open plan's `Resume at` could not be read from existing docs · git log, list it here.
- The only question is the closing one: `Shall I make the overlay plan with this scope · profile?` No other line carries a question mark.
- If the user corrects rows (P1–P9) or scope (actions · skips), recompute the scope and show it again in the same shape, with the same closing question.
- Once approved, go to section F. If it was typed by mistake in a project that must not be overlaid, it stops here; nothing was made before approval.

## D. Stop reasons

Stop if any one of the four below holds.

| Reason | Way to fix |
|---|---|
| 1. A git (the umbrella or even one repo) has unsaved changes | Commit or clear them, so overlay commits do not get mixed in. If the analysis tests changed tracked files, fix those tests so they do not write files |
| 2. Tests fail in a repo in scope | Fix them as normal work, so nothing is red from the first commit that turns the gates on |
| 3. A real secret is in git (history included) | Rotate the key in the `templates/docs/runbook-secret-rotation.md` shape. The user decides whether to rewrite history |
| 4. gitleaks is missing | Install it (macOS `brew install gitleaks`) |

- Reason 1 holds when, in any block of the section B 1 shell (before install · tests), `changed` is not 0, or the `untracked` lines hold anything other than cache folders (section B 2; those left by a previous analysis's tests included). A tracked file changed in the before/after comparison of section B 2 is also reason 1. If `untracked` is not 0, look at those lines with `git -C <folder> status --short`.
- The stop message starts with the one line `Overlay stop: <reason>`. `<reason>` is the sentence of the table's reason cell as it is, without its number (two or more joined with ` · `). Then show the analysis (the section C shape minus the closing question) and the ways to fix, and end with "Fix these, then type `/groundwork:new` again in this folder". No closing question. No files.
- Not stop reasons: secret-scan false positives (listed in the analysis as allowlist candidates), tests of skipped repos (not run), cache folders made by the analysis's install · tests (section B 2), repo folders visible in the umbrella `git status` (subfolders with a `.git`; T1 fixes the umbrella `.gitignore`).

## E. Code signals → P1–P9

This table turns the signal words of `reference/profile.md` B into code signals. Look in dependency names (manifests) · folders · environment variable names (`.env.example` · config module) · workflows. If even one is there, yes; otherwise no. Write the signal's name as the reason and its file · folder as the reason path. If a signal is unclear, set yes and write 'estimate' in the reason (the same rule as `profile.md` B). The rest of the `profile.md` B rules (tokens · refunds are not P9 signals; small CLIs · scripts · libraries are usually P8 no) hold as well.

| Row | Code signals |
|---|---|
| P1 | Payment SDK dependencies (`stripe` · a payment provider SDK), `amount` · `balance` · `price` · `fee` · `points` columns in schemas · models, decimal math libraries (`decimal.js` · `big.js` · `bignumber.js`) |
| P2 | cron · queue libraries (`bullmq` · `node-cron` · `celery` · `rq` · `apscheduler`), `worker` · `jobs` · `queue` folders, scheduled workflows (`on: schedule`), deploy config with several processes (`Procfile` · two or more compose services) |
| P3 | Routes open without login · webhook receiver handlers, upload (`multer` · `python-multipart`) · websocket (`ws` · `socket.io`) libraries, proxy config |
| P4 | LLM SDK dependencies (`openai` · `@anthropic-ai/sdk` · `anthropic` · `ai` · `langchain`), a `prompts/` folder, environment variables such as `OPENAI_API_KEY` · `ANTHROPIC_API_KEY` |
| P5 | i18n libraries (`next-intl` · `i18next` · `react-intl` · `gettext`), locale folders (`locales/` · `messages/` · `i18n/`), sitemap · `hreflang` |
| P6 | Several apps (`apps/*` · admin · docs site folders), two or more app packages in the workspace |
| P7 | Payment · chain · auth SDK and external data provider client dependencies, their key environment variables |
| P8 | Commit count · contributor count · history length (`commits` · `authors` · `first` of the section B shell). Yes needs a history spanning more than a few weeks or two or more contributors. Open plans alone are not a yes. For a small CLI · script · library the `profile.md` B rule (usually no) wins even with this signal |
| P9 | Wallet · signing libraries (`ethers` · `viem` · `web3` · `wagmi` · embedded wallet SDKs `@privy-io/*` · `@dynamic-labs/*`), private key environment variables (`PRIVATE_KEY` · `MNEMONIC` · `*_SIGNER_KEY`), contract folders (`contracts/` · `foundry.toml` · `hardhat.config.*`), withdrawal · transfer · order signing code |

## F. After approval

In this order.

1. **One module message.** For each row that is on, read the `## Questions (one message)` of `reference/modules/Pn.md` and gather them in one message. Fill each number's recommended answer from existing facts (code · config · docs) and attach the reason path. Ask only the numbers facts could not fill ("as recommended, or just the numbers to change"). If all are filled, just show it and go to 2. If the baseline pieces T3 will fill need answers, put the numbers of the baseline message (`reference/baseline.md` section C) in the same message the same way. When two or more modules come together (baseline included), write numbers as row and number, like `P1-2` (baseline: `baseline-1`). Keep it unambiguous which module's number a "just the numbers to change" answer refers to.
   - ADRs follow the `## ADR` of each `Pn.md`. A decision the current code has already made is written as "record of an existing decision" with its reason path. Only decisions to change are asked anew.
2. **Plan draft and profile table in one commit.** Write `docs/plans/<YYYY-MM-DD>-overlay.md` in the section G shape (superpowers:writing-plans shape, with the path set to this name). The head is `> Status: draft` and `> Resume at:`. In `CONTEXT.md` write the confirmed `## Project profile` table in the `reference/profile.md` D shape. Put the plan · `CONTEXT.md` · the ADRs from 1 in one commit: `docs(plans): draft the overlay plan`.
   - If it breaks off before this commit, there is no profile table, so typing it again starts the overlay over. If it breaks off after the commit, section A 1 resumes the plan.
   - For an umbrella, commit in the umbrella git. If the umbrella has no `.git`, do not commit; leave it for T0's first commit.
3. **Plan approval.** Show the plan and pass the late-stage-2 approval gate like any other plan (one question). Do not ask about each overlap separately. Once approved, change it to `approved (date)`, commit and execute. Execution follows the stage 5 rules (with P8, side branch · the two checks; otherwise straight on main). Do the tasks in order, set `active` at the first task, and update `Resume at` per task. Commits are per feature.

## G. Overlay plan shape

The head is the same as other plans (for an umbrella, line 2 names the repos in scope with `> scope:`). Put `overlay plan` in the H1. Section A 1 recognizes an overlay plan by those words.

```
# <project> overlay plan

> Status: draft
> Resume at: T1 docs · rules — from the inventory
```

Task order: ① docs · rules (T1) → ② gates · violation baseline (T2) → ③ missing stage 4 pieces (T3).

- **T0 `git init`** — only for an umbrella with no `.git`. `git init -b main`, a `.gitignore` that leaves out the repo folders, and the section F 2 plan · profile table in the first commit.
- **T1 docs · rules** — make the inventory first. Then move the docs · rules rows of the table below (`CLAUDE.md` · docs locations · open plans · specs · handoff · ledger · status board · `.claude/settings.json` · `.gitignore` · ADRs · runbooks). The `CLAUDE.md` template's placeholders are filled from facts in the existing docs · code; `{{docs_language}}` takes the language in use when the analysis was approved (SKILL.md **Language**).
- **T2 gates · violation baseline** — move the lint · format tool, existing hook tools and the CI · hook rows, and turn the gates on. The violation baseline follows section H. Even when the formatter changes, do not reformat existing files (every file would become 'touched'). Format violations go into the violation baseline like lint violations.
- **T3 missing stage 4 pieces** — per repo (for an umbrella, one task per repo). Fill whatever is missing of what the stage 0 table's "Resume 4" row looks for (`ci.yml` · `CLAUDE.md` · `check-contrast.mjs` with a UI · `e2e/` on the web) and what stage 4 puts in (baseline scope · the `## Scaffold` of modules that are on · per-form outputs). The design row goes here too. Gates newly turned on in this task (contrast · banned patterns · a11y) are wrapped per section H as well. Archive repos and stacks with no template are not done.
- **Model field** — write `Model: Opus` or `Model: Sonnet` per task. Tasks touching money · secrets · auth and tasks with an inventory check run on Opus (`reference/conventions.md` `## Subagent models`).
- Shrinking the violation baseline (fixing existing violations) is not included. It shrinks as later work touches the files.

**Inventory check.** A task that moves `CLAUDE.md` · docs · CI · hooks · lint config first makes a list of the old ones. The list lives in `.superpowers/overlay/inventory.md` at the root (the main checkout; for an umbrella, the umbrella folder). Not inside a P8 side branch worktree (it would vanish with the worktree after merge). Not committed (if `.gitignore` lacks `.superpowers/`, add it first).

```
| # | Old place | What | New place |
|---|---|---|---|
| 1 | `CLAUDE.md` line 12 | rule: migrations only as SQL files | `CLAUDE.md` hard rule 3 |
| 2 | `.github/workflows/deploy.yml` | job `deploy` | kept — in place |
```

- One per row: rules · commands · Mistakes log lines · doc headings · workflow jobs · hook checks · old lint · hook tool config files · their dependencies.
- The moving task fills the new-place cell. Things left as they are get "kept — in place"; a cleaned-up config file gets where its rules went.
- The task review runs on Opus. It checks every list row against its new place and does not pass a row with an empty new place.

**Moving rules** (T1–T3 follow them).

Common: nothing is deleted. Move (keeping history with `git mv`) or merge. After a move, fix links that pointed at the old place. IDs (`DEF-n`, etc.) are not renumbered.

| Target | Action |
|---|---|
| `CLAUDE.md` (repo · umbrella) | Rewrite in the template shape, with its `- Docs language:` line. Move every existing rule · command · Mistakes log entry into its template slot. What goes over the size cap (repo 20,480B · umbrella 8,149B) is sent to its proper place per the `docs-rules.md` table (`CONTEXT.md` · runbook · ADR). Write in the commit body what moved where |
| Docs locations | Follow the `docs-rules.md` table. Specs · plans elsewhere (e.g. `docs/superpowers/`) move to `docs/specs` · `docs/plans`. Finished specs · plans move to `docs/archive/` |
| Open plans · specs | Add the `/groundwork:new` head (`Status:` · `Resume at:`). A plan with no checkboxes gets its remaining work moved into a checklist. `Resume at` is read from existing docs · git log; if it cannot be, it goes into the analysis message |
| Handoff · ledger · status board | If the profile table turns P8 on, move them into the `templates/docs/{handoff,ledger,status}.md` shape, moving every existing row · item. With P8 off, existing ones stay and none are created |
| `.claude/settings.json` | Merge with the template values. deny and ask are the union; allow keeps the existing entries and adds the template's. Existing hooks stay |
| `.gitignore` | Add the template lines |
| CI · hooks | `ci.yml` · `pre-commit` take `/groundwork:new`'s as the base. Jobs of existing workflows that `/groundwork:new` lacks (deploy · release · scheduled jobs, etc.) stay as they are. Checks the existing hooks ran that `/groundwork:new` lacks stay too |
| Missing stage 4 pieces | Fill everything the stage 0 table's "Resume 4" row looks for (`ci.yml` · `CLAUDE.md` · `check-contrast.mjs` with a UI · `e2e/` on the web) and the baseline scaffold pieces. After the overlay, stage 0 must not land on that row. a11y violations of existing screens go into the violation baseline (keyed by screen path) |
| lint · format tools | If they differ from the template tools (e.g. eslint · prettier · black), replace them with the template tools (by design). Rules of the existing config the new tool can express move over; rules that cannot move are listed in the analysis message. Existing violations go into the violation baseline. Old config files and dependencies are cleaned up after they are listed in the inventory |
| Existing hook tools (husky · lefthook, etc.) | Replace with `/groundwork:new`'s `.githooks` · `core.hooksPath`. Checks the existing hooks ran that `/groundwork:new` lacks are moved into `.githooks/pre-commit` and kept. Existing tool config files are cleaned up after they are listed in the inventory |
| Design (with a UI) | No design interview. Transcribe the current screens' colors · fonts · spacing into `DESIGN.md` and tokens. The contrast · banned-pattern gates turn on with a violation baseline. A new design is separate work |
| ADRs · runbooks | If an ADR · runbook that the modules of rows that are on would make already exists with the same content, move or merge that file. Otherwise create it |

## H. Wiring the violation baseline

The task that turns a gate on (T2, and gates newly turned on in T3) does it on the spot. The violation baseline is, per gate, the list of files that have violations now. Files not on it must pass the gate as is. When a commit touches a file on it, fix that file's violations and take it off the list.

**Tool.** Copy `templates/gates/baseline.sh` to `scripts/baseline.sh` (for an umbrella, into every git whose gates it wraps).

```
bash scripts/baseline.sh <gate> [--key <ERE>] [--write] -- <command> [args...]
```

- `<gate>` matches `^[a-z0-9][a-z0-9-]*$` (e.g. `lint` · `types` · `docs` · `banned` · `a11y`). Each wrapped command gets its own name.
- The list is `.baseline/<gate>.txt` at the git top level: sorted keys, one per line, committed.
- The command runs at the git top level. Without `--key`, the keys are the paths printed in the output that git knows as files (tracked · new and not ignored). Line numbers are dropped. A path holding a blank or one of ``:<>"'`,;=|`` cannot become a key, so this gate cannot guard it. A path holding characters outside ASCII letters · digits · `_@./+-` (non-ASCII letters · `[]` · `()`) also cannot become a key when it is printed with other characters glued before or after it (`→app/[id]/page.tsx` · `docs/résumé.md’s`). A fragment of a path that cannot become a key may be caught as another file's key.
- Exit codes: 0 pass · 1 gate failure · 2 usage · config error. Problem lines start with `baseline <gate>: ` (e.g. `baseline lint: new violation: src/a.ts`). There are five failures: a failed run whose output has no key, a new violation not on the list, a list grown past the base, a line left after the fix, a touched file still violating (file keys only). `--write` checks only the first one and `would grow` (a key the base's list lacks).
- The base for comparison is `BASELINE_BASE` (`HEAD` if unset). An empty value is not read as `HEAD`; it stops with 2. A list can be created only when the base lacks that file. There is no other bypass, such as a commit-message marker · environment variable.

**Wrapping.**

1. At overlay time, wrap only gates that have violations. Gates with none stay as they are.
2. For each gate, first make the list once with `bash scripts/baseline.sh <gate> --write -- <command>`. `--write` skips the touched-file check, so it never goes in `{{cmd_check}}` · CI. Use it only for this one first creation.
3. Replace that command inside the `{{cmd_check}}` chain with `bash scripts/baseline.sh <gate> -- <command>`.
4. Run `{{cmd_check}}` and see green. See green once more with `BASELINE_BASE=<the section F 2 plan commit> {{cmd_check}}` (CI compares with the commit before the push, so files T1 touched count as 'touched' too; for an umbrella's repo, the commit before the overlay's first commit in that repo). Files caught here as `touched but still violating` are files the overlay already touched, so fix them in T2 and take them off the list. Then put `.baseline/` in one commit with the gate wiring.

- Wrap the tool itself. Do not wrap `make` · `pnpm run <script>` (the `Makefile` that GNU make prints becomes a key). `pnpm exec <tool>` works. E.g. `bash scripts/baseline.sh lint -- pnpm exec biome ci .` · `bash scripts/baseline.sh types -- pnpm exec tsc --noEmit` · `bash scripts/baseline.sh lint -- uv run ruff check .` · `bash scripts/baseline.sh docs -- bash scripts/check-docs.sh`. Tools that look at the whole project at once (`tsc`, etc.) are filtered by the file paths in their output too.
- Pick an output format that prints only violation lines. Paths a failed run prints become keys even when they come from warnings · config hints, and such a file then shows `touched but still violating` every time it is touched, even with nothing to fix.
- A tool that prints only absolute paths (eslint's default output, etc.) yields no keys and always fails. Pick an output format with relative paths. The overlay replaces eslint with the template tool, so this does not usually come up.
- Gates whose output has no file paths set their keys with `--key`. `--key` has no touched-file check.
  - a11y (keys are screen path and size): `bash scripts/baseline.sh a11y --key '/[^ ]* \((default|phone)\)' -- pnpm exec playwright test e2e/a11y.spec.ts --reporter=line`. This command goes in the `package.json` `e2e` script, not in `{{cmd_check}}` (local · CI · P8 `verify` all call that script). The script chains three with `&&`: build → `playwright test --grep-invert a11y.spec.ts --pass-with-no-tests` (the specs other than the a11y spec; `--grep-invert` also matches file names) → the command above. The a11y spec runs separately: a run wrapped with `--key` passes when all its keys are on the list, so running them together would hide other specs' failures. Inside `package.json`, write `\` as `\\`.
  - Contrast (keys are theme and text · background pair): `bash scripts/baseline.sh contrast --key '(light|dark) [^ ]+ on [^ ]+' -- node scripts/check-contrast.mjs design/tokens.json design/contrast-pairs.json`.
- Tests and gitleaks are not wrapped. Failing tests and real secrets are stop reasons in the analysis (section D). Secret-scan false positives are handled with `.gitleaks.toml` allowlisting.
- The `check-docs` of the umbrella docs hook (`.githooks/pre-commit`) is wrapped the same way: `bash scripts/baseline.sh docs -- bash scripts/check-docs.sh || exit 1`. The umbrella `scripts/` gets `baseline.sh` too. In the hook the base is `HEAD`.
- When a list empties (its last line is deleted), delete the list file and the wrapping together in that commit. From then on that gate runs unwrapped.

**CI.** The `ci.yml` checkout uses `fetch-depth: 0` (the base commit must be there; `persist-credentials: false` stays). Pass the base to the check step. If a11y is wrapped, the `e2e` job also gets `fetch-depth: 0` on its checkout and the same `env` on its `pnpm e2e` step: copy the two `env` lines under `- run: {{cmd_check}}` below to under `- run: pnpm e2e`, with `env:` at the indent of `run:`.

```yaml
      - uses: actions/checkout@<pinned SHA as is> # v<version>
        with:
          persist-credentials: false
          fetch-depth: 0
      …
      - run: {{cmd_check}}
        env:
          BASELINE_BASE: ${{ github.event.pull_request.base.sha || github.event.before || github.sha }}
```

A PR compares with the base branch's commit, a push with the commit it replaced. A manual run (`workflow_dispatch`) has both of those empty and compares with its own commit. An empty value makes `baseline.sh` stop with 2, so `github.sha` comes last.

## I. Umbrella

- Umbrella docs · rules move per the section G table, just as for a single repo (`CLAUDE.umbrella.md.tmpl` · the umbrella docs hook, `reference/baseline-scaffold.md` 'Umbrella docs hook').
- Each repo fills only its missing scaffold pieces, as in "Resume 4" (T3). What already exists is moved or merged per the section G table.
- Skipped repos are archive repos and stacks with no `/groundwork:new` template (e.g. Solidity · Foundry). List them in the analysis message as 'Skipped' with the reason, and get them confirmed together with the user's approval. Their tests are not run and they are not scaffolded.
- A skipped repo stays in the umbrella `## Repo map`, with `skipped (<reason>)` in its row's `Done gate` cell. A re-typed `/groundwork:new` (stage 0 umbrella resume) does not scaffold this repo.
- Existing names that differ from the repo map naming rule (`<name>-fe`, etc.) are not renamed. The map uses the real names, and the umbrella `.gitignore` is written to cover the real repo folders. Commit scopes use the repo map names.
- If P8 is on but the repo folders are not of the `<name>-*` form (`trunk.sh` finds repos only through the `<name>-*/` line of the umbrella `.gitignore` and folders of that name), say so in one line in the analysis message: as it stands, trunk treats this umbrella as a single repo. The user decides whether to rename. The default is not to rename.
- For an umbrella that had no `## Repo map`, T1 writes the map with the names · roles estimated in the analysis and approved.
- Commits go per repo, per the umbrella mode of the `SKILL.md` commit rules.

## J. End report

- When the overlay plan's last task is done and the plan is closed, end with the normal five-line resume report.
- Put three things before it.
  - The list of what moved · merged (what → where, from the inventory)
  - The list of what was kept (left as it is because `/groundwork:new` lacks it)
  - The remaining violation-baseline count per gate (`find . -path '*/.baseline/*.txt' -not -path './.worktrees/*' -exec grep -cH '' {} +`)
- Before the report, run the stage 0 state shell once and check that the table goes to ①–④, not "Resume 4" (for an umbrella, leaving out the repos marked `skipped` in the map).
- If work was in progress before the overlay, that work is the next step (per the ①–④ judgment as it stands).
