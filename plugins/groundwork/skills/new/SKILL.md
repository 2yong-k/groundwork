---
name: new
description: Use when the user types /groundwork:new in a brand-new or empty project folder to start a software project from scratch, or types /groundwork:new again in a folder where that kickoff is only partly done and must continue from where it stopped, or types /groundwork:new in an existing project that /groundwork:new did not start, to overlay its conventions. Covers both a single repo and an umbrella folder that holds several repos (fe/be/infra/…).
argument-hint: "[one-line project purpose (optional)]"
disable-model-invocation: true
model: opus
effort: xhigh
---

# /groundwork:new — start a new project: interview → skeleton → design lock → scaffold → first task

**Files.** Skill dir: ${CLAUDE_SKILL_DIR} · plugin root: ${CLAUDE_PLUGIN_ROOT}. reference/… and templates/… below, and <skill-dir>/… or <plugin-root>/… inside them, mean files there; read them with the Read tool by absolute path and never cd there. Never write either path into a project file: a project points at groundwork only through the groundwork:reference skill.

**Language.** Setting: ${user_config.language} (empty, or shown as a literal placeholder → English). A project's CLAUDE.md line "- Docs language: <lang>" wins over the setting; if the two differ, say so once. Talk to the user, and write every document you fill from the user's answers — CONTEXT.md, ADRs, specs, plans, the handoff, ledger rows — in that language, template prose included. Files copied as they are (runbooks, gates, the status board, security levels) stay English. Markers stay English everywhere (Status:, Resume at:, ## Project profile, ## Stage 1 summary, ## Repo map, Side branch:, Milestone:, Start at:, …), as do code, identifiers and commit messages.

The user is a developer; language follows **Language** above. The rules in `reference/conventions.md` (interview; glossary and ADRs; engineering rules — YAGNI ladder, TS strict/ruff, conventional commits, design tokens, no AI-default aesthetics; subagent models) apply too — read it once at the start. Commit straight to main (branch only when asked; with P8, stage 5 plan runs go in a side branch).

If a superpowers: skill named here is not available, stop and ask the user to run /plugin install superpowers@claude-plugins-official.

**Four principles.** ① Decisions come from the user, facts from the environment — never ask what files or tools can tell you. ② **Exactly one** question per message — never tack a side question such as "…and also tell me …" onto the end. Every question carries your recommended answer and the reason (`reference/conventions.md` `## Interview`). Exception: a **module message** (the baseline, each module that is on) puts a numbered list with recommended answers and reasons in one message and asks "as recommended, or just the numbers to change"; then follow up only the changed numbers, to the end. ③ Create no files before passing the approval gate that ends a stage (exception: `CONTEXT.md` and `docs/adr/` during interviews). ④ Commit what you made **right away** when its stage ends ("Commit rules" below) — commit without asking, but report what you committed with which message. Never push.

## 0. State check (always first)

1. If cwd is home (`~`) or a drive root, **stop**. Tell the user to create a folder such as `~/git/<project-name>` and type `/groundwork:new` there again.
2. **Overlay** — (a) If `docs/plans/????-??-??-overlay.md` is not `done`, `dropped` or `superseded`, start from that plan (`draft` → its approval question, `active` → its `Resume at`). (b) Otherwise, if there are already several source files (`src/`, `app/`, package folders, Go modules, sub-repos — anywhere) but `CONTEXT.md` has no `## Project profile`, this is an **overlay onto an existing project**. Either way, read `reference/overlay.md` and do what it says; skip the table below and steps 3 and 4.
3. If cwd's `CLAUDE.md` has a `## Repo map` section, this is **resuming an umbrella folder (multi-repo)** — use "Umbrella state check" below.
4. Otherwise (single repo), judge from the outputs how far the stages got. Collect state in **one** shell call — read no file bodies, only the shell output (what exists, the spec's first line, plan box counts, statuses, `Resume at`, handoff sections 1-3, change count, rows that are on, the P9 row).

```bash
ls -A; ls docs/specs docs/plans docs/design design scripts .github/workflows 2>/dev/null; grep -rm1 '' docs/specs 2>/dev/null; grep -rc '^- \[ \]' docs/plans 2>/dev/null; grep -rc '^- \[x\]' docs/plans 2>/dev/null; grep -rEm2 '^>? ?(Status|Resume at):' docs/plans docs/specs 2>/dev/null; awk '/^## /{on=/^## [123]\./} on' docs/plans/handoff.md 2>/dev/null; grep -E '^\| P([1-9][^|]*\| yes |9 )' CONTEXT.md 2>/dev/null; grep -l '^## Project profile' CONTEXT.md 2>/dev/null; ls docs/adr 2>/dev/null; git status --short 2>/dev/null | wc -l
```

| What the folder holds | Next stage |
|---|---|
| Empty (README, LICENSE or `.git` alone count as empty) | 1 |
| Only `CONTEXT.md` (no profile table) or `docs/adr/` | 1 (from the summary recheck) |
| `CONTEXT.md` with the `## Project profile` table, no spec | **Resume 2** — skip the profile check; start at the first module with no ADR |
| `docs/specs/*-design.md`, no `docs/plans/` | Late stage 2 — writing-plans |
| `docs/plans/*.md`, no manifest | 3 if there is a UI and no `DESIGN.md` (umbrella: `docs/design/`), else 4 |
| Manifest + `.git` but no `ci.yml`, `CLAUDE.md`, (UI) `check-contrast.mjs` or (web) `e2e/` | Resume 4 (missing pieces first) |
| Manifest (`package.json`, `pyproject.toml`, `Makefile`) + `.git` + CI | The first of ①–④ below that matches (= the next step) |

① `docs/plans/handoff.md` has items in sections 1-3 → read sections 0-3, re-arm the section 2 schedules, tell the user what section 3 holds, then start at section 1 (if it is empty, from ②; if it disagrees with an `active` plan, say so and follow the plan) ② a plan with status `active` → from that plan's `Resume at` ③ an `approved` plan → 5; an `approved` spec whose paired plan is missing, `draft` or `dropped` → late stage 2 ④ anything else → report "no work in progress" and wait for the user's next task

A `draft` spec starts from its approval question; a `draft` plan from late stage 2.

When resuming, report the five lines below **verbatim**, then read the next stage's files and put **the first question in the same message** (except for ④, never just report and stop). For ①, ② and late stage 2, do that work first (late stage 2: writing-plans), and open the first question or closing message the user sees with these five lines (as of the resume).

```
Project: … (first line of CLAUDE.md or the spec)
Stages done: … / Stages left: …
spec: path or none · plan: path or none · design: locked/none · profile: P1·P2·… or none
Uncommitted changes: none / N files
Next step: …
```
If there is no P9 row, read it as `no` and end the report with `No P9 (money-moving keys) row — tell me if it applies`.

### Umbrella state check
Umbrella folder = a docs-only git + repo folders (`<name>-fe`, `<name>-be`, …, each its own git). State is collected in one shell call too:

```bash
ls -A; ls docs/specs docs/plans docs/design 2>/dev/null; grep -rEm2 '^>? ?(Status|Resume at):' docs/plans docs/specs 2>/dev/null; awk '/^## /{on=/^## [123]\./} on' docs/plans/handoff.md 2>/dev/null; for d in */; do g=-; m=-; c=-; n=-; [ -d "$d.git" ] && g=git && n=$(git -C "$d" status --short | wc -l | tr -d " "); { [ -f "$d"package.json ] || [ -f "$d"pyproject.toml ] || [ -f "$d"Makefile ]; } && m=manifest; [ -f "$d"CLAUDE.md ] && c=claude; echo "$d $g $m $c dirty=$n"; done; grep -E '^\| P([1-9][^|]*\| yes |9 )' CONTEXT.md 2>/dev/null; echo "umbrella dirty=$(git status --short 2>/dev/null | wc -l | tr -d " ")"
```

The report is the five-line form with the second line per repo: `Repos: <name>-fe = scaffolded (git·manifest·CLAUDE.md) · <name>-be = no folder · …`. The fourth line is `Uncommitted changes: umbrella N / fe N / …`. Next is stage 4 (scaffold) of the repos in the repo map that are not finished (except those marked `skipped` there); if all are there, ①–④ above.

## 1. Discovery interview — what are we building

An argument after `/groundwork:new` is the first answer to **Purpose**; start from the next question. Cover all six groups below; when an answer wavers, follow that branch to the bottom.

1. **Purpose** — when this project is done, what should exist in the world? One sentence.
2. **Users** — who uses it, in what situation, and why? Pick a single primary user.
3. **Three core scenarios** — what users do, as verbs. If these three fail, the project has failed.
4. **Out of scope** — state what this round will not do (offer candidates such as payments, i18n, mobile app, admin to choose from).
5. **Done criteria** — what state means v1 is finished? Make it measurable.
6. **Constraints** — deadline, platform (web/mobile/CLI/API), deploy target, budget (how far paid services are allowed), existing assets (design, data, domain).

When a term comes up, record it on the spot in the `CONTEXT.md` glossary as `reference/conventions.md` `## Glossary and ADRs` says (the signal is the moment one thing gets two names).

At the end, summarize the six groups in 10 lines or fewer → gate **"Shall we go ahead with this?"**. Once approved, write the summary to `CONTEXT.md` `## Stage 1 summary` and commit it with the ADRs (no git yet → `git init -b main`): `docs: capture product context and glossary`. The summary recheck (stage 0 table) shows the summary and a list of the gaps found (as statements) and asks only one question: **"Fix these first, or go on as is?"**

## 2. Skeleton interview — how do we build it

Ask in the order below. `(Pn)` only for modules that are on: read `reference/modules/Pn.md` right there, ask in **one module message**, and right after the answer write the ADR as that file's `## ADR` says (placeholders the answer leaves open take the recommended answer, marked "recommended default").

1. **Profile check** (`reference/profile.md`) — a P1–P9 estimate table with reasons → "Correct only the wrong cells". Once confirmed, write it to `CONTEXT.md` `## Project profile` and commit `docs: record the project profile`.
2. **Number of deploy units** — "Single vs umbrella" below.
3. **Client form** (`reference/client-forms.md`; skip if there is no UI) → **Stack** (the defaults below as the recommended answer; per repo for an umbrella).
4. (P5)
5. **Runtime and deploy target** → **baseline message** (`reference/baseline.md` section C; native or webview: 2a onward included).
6. **Data and storage** (what is kept permanently, and where) → (P1) (P9) (P2)
7. **Auth** (is it needed, who provides it) → (P3)
8. **Module boundaries** (the three most important boundaries and the interfaces between them) → (P6) (P7) (P4)
9. **Test strategy and done gate**
10. **Hard rules** (3–7 things never to do: deploys, secrets, data loss, external calls, …)
11. (P8)

A resume skips 1 and every slot that already has an ADR in `docs/adr/` (modules, `environments`, `release-model`, stack, …).

| Kind | Recommended default (per the engineering rules) |
|---|---|
| Web app | Next.js App Router · React · TypeScript strict · pnpm · Biome · Tailwind (tokens as CSS variables) · Playwright e2e |
| Native app | Expo · React Native · TypeScript strict · pnpm · Biome · EAS Build/Submit/Update · device e2e (Maestro or similar) |
| API server | NestJS + TypeScript strict + Jest, or FastAPI + Python 3.12 + uv + ruff + pytest |
| Scripts / data | Python 3.12 + uv + ruff + pytest |
| CLI | TypeScript (tsx) or Python — same tools as above |

**Single vs umbrella.** One independently deployed and versioned unit → a single repo (cwd is the repo). Two or more (fe, be, infra, contract, …) → **umbrella mode**: cwd becomes the umbrella folder and each repo is created inside it as `<cwd name>-<unit>`. Recommendation: a small product built alone → single; fe and be with different release cycles or stacks, or any infra or contract → umbrella. Umbrella mode has one docs rule — **spec, plan, decision and design docs live only in the umbrella `docs/`** (no `docs/` inside a repo), and line 2 of each spec and plan names the repos it touches: `> scope: fe` / `fe+be` / `all`. A repo holds only its own `CLAUDE.md`, excluded through `.gitignore`.

For every decision that is hard to reverse (stack, storage, auth, boundaries), leave `docs/adr/NNNN-<slug>.md` in the ADR format of `reference/conventions.md` `## Glossary and ADRs`. Commit the stage 2 ADRs in one go before brainstorming: `docs: record skeleton decisions`.

Then write the spec with **REQUIRED SUB-SKILL** superpowers:brainstorming. Do not re-ask answers already collected, and do not start the visual companion (screens are stage 3). Always read `templates/spec-sections.md` and pass on its head rules and the sections of the modules that are on (native: the native sections too) as the instruction "include these sections in the spec". **Set the spec path to `docs/specs/YYYY-MM-DD-<topic>-design.md`** (not the default `docs/superpowers/` path). After the spec is approved, **REQUIRED SUB-SKILL** superpowers:writing-plans → `docs/plans/YYYY-MM-DD-<topic>.md` (same rule). A spec and a plan carry `> Status: draft` within their first 15 lines; right after each is approved, change it to `approved (date)` and commit: `docs: add <topic> design spec` · `docs: add <topic> implementation plan`.

## 3. Design interview — only when there is a UI

The goal is to shut out "looks AI-made" defaults from the start and lock the decisions into **the token source `design/tokens.json`**. Read and follow `reference/design-interview.md` for this stage's rules.

1. Eight interview questions (tone, references, type, color, density, shape, motion, bans) — one at a time.
2. Copy `templates/directions.html` to `docs/design/directions.html` and fill in **three directions**. All three render the same sample screen (header, hero, card list, form, table, button states, empty state) with **the real copy from stage 1**, and their color variables map 1:1 to the `color` keys of `templates/design/tokens.json`. Light and dark both.
3. Check it yourself before showing it: inside Weft with the weft-browser skill available, use it to `weft browser open file://…` and take a screenshot; otherwise `open` (macOS) or `xdg-open` (Linux) `docs/design/directions.html`. If anything trips the ban checklist or the contrast check (design-interview section D), fix it before showing.
4. When the user picks or mixes → the lock outputs of design-interview section E. **Lock gate:** 0 empty cells in `tokens.json` · generator run · contrast check green in both themes — show the output and ask **"Lock these tokens?"**. Umbrella mode: the sheet and `DESIGN.md` go in the umbrella `docs/design/`; the rest, being code, goes in the **fe repo** `design/` (create the fe folder and git here if missing). Once locked, commit: `docs(design): add direction sheet` · `feat(design): lock tokens for <direction name>` (`design/tokens.json`, generated files, `contrast-pairs.json`; for an umbrella, in the fe repo).

Projects with no UI (API, CLI, scripts) skip this stage.

## 4. Scaffold — done only when every gate passes on the empty skeleton

Before starting, ask once: **"Start the scaffold?"** (installs and git init). Even on resume it comes first; missing baseline answers come after. Go in order and keep whatever already exists. What goes in is set by the baseline scope (`reference/baseline.md` section B; empty cells are not built), the `## Scaffold` of each module that is on, and the per-form outputs (`reference/client-forms.md` section C).

1. No `.git` → `git init -b main`.
2. Package manager init (B10 settings before installing) → lint and format (Biome/ruff) → type check (tsc strict, ty or mypy strict) → test runner → tie them into a one-line gate (a `pnpm check` script or `make check`).
3. Create folders along the spec's module boundaries. Per boundary: an empty index, one test file (so the runner runs one test) and a boundary import check (`reference/baseline-scaffold.md`).
4. `.gitignore` (language standard + `.superpowers/` + `.worktrees/` + `.env*` + `!.env.example`), `.env.example` (key names only, purpose in a comment), `.claude/settings.json` (`templates/claude-settings.json`).
5. If a generator (`create-next-app`, …) was used, **delete its boilerplate**: default landing, logos, gradients, the `system-ui` stack, example components. Wire the generated `design/tokens.css` (native: `design/theme.ts`) into the global styles and leave only an empty layout that follows the `DESIGN.md` conventions.
6. Build the outputs and checks of the baseline and each module that is on, and tie them all into the one-line gate from 2. Gate file locations and filling `ci.yml`: `reference/baseline-scaffold.md`. Right after copying the secret-value hook: `chmod +x .githooks/pre-commit && git config core.hooksPath .githooks`. Native: `app.config.ts`, `eas.json` and the `eas-build` job in `ci.yml`.
7. With a UI, put token swatches (color roles, type sizes, motion, focus) in both themes on an **empty component-kit screen** (dev only). From the first task on, register each component as it is built.
8. Make `CLAUDE.md` from `templates/CLAUDE.md.tmpl` — one screen, **rules only** (state and history live in docs and git). Filling: `reference/baseline.md` section D. Single repo: `{{docs_root}}`=`docs`, `{{context_path}}`=`CONTEXT.md`, `{{docs_rule_extra}}` an empty line, `{{restart_dir}}`=`this folder`.
9. Actually run the gate and show its output (1 test passing, 0 lint and type errors, checks green, hook wired). Run the `.worktrees/` probe too (`reference/baseline-scaffold.md`). Never push a failure off to "later".
10. Once green, commit right away, per concern — `chore: bootstrap project skeleton` · `ci: add required checks and secret scanning` · `feat(design): add contrast and banned-pattern checks` (UI) · `chore: add the heavy-command lock` (P8) · `chore: add app config and EAS profiles` (native) · baseline security commits: `reference/baseline-scaffold.md`. If generator boilerplate was stripped and tokens wired, a separate commit `refactor: strip generator boilerplate and wire design tokens`.

### Umbrella scaffold
1. Umbrella folder: `git init -b main` (if missing) → `.gitignore` with `<name>-*/`, `.worktrees/`, `.superpowers/` and OS junk files → `CLAUDE.md` from `templates/CLAUDE.umbrella.md.tmpl` (repo map, docs rules, shared hard rules, **7.9 KB or less** — every sub-repo session loads it automatically) → the docs hook (`reference/baseline-scaffold.md`) → commit `chore: bootstrap umbrella docs`, `docs/` and `CONTEXT.md` included.
2. For each repo, create the folder `<name>-<unit>` and run single-repo steps 1–9 above as they are (baseline: only the scope for that repo kind). Repo `CLAUDE.md`: `templates/CLAUDE.md.tmpl` with `{{docs_root}}`=`../docs`, `{{context_path}}`=`../CONTEXT.md`, `{{docs_rule_extra}}`="Do not create docs/ inside this repo. List this repo in the > scope: on line 2 of each spec and plan.", `{{restart_dir}}`=`the umbrella folder (..)`. Add `CLAUDE.md` to the repo's `.gitignore`. The token source is the one `design/tokens.json` in the fe repo — other UI repos copy it with `sync-tokens.sh` and tie `--check` into their gate.
3. Commit per repo (the commits of step 10 above, in each repo). If a repo shows up in the umbrella folder's `git status`, the `.gitignore` pattern is wrong.

## 5. First task

With P8, before the first task create whichever of the ledger, handoff and status board is missing (milestone `v0.1.0`, the `reference/modules/P8.md` scaffold) and commit: `docs: add the ledger and handoff` (umbrella: in the umbrella `docs/`).

Propose 1–3 first tasks from `docs/plans/`, numbered, with estimated size. When the user picks, hand off to superpowers:executing-plans (in a session not on Fable: one at a time → superpowers:subagent-driven-development; several tasks with no overlapping files → ask once and, if agreed, a Workflow). Do not start before the pick. In umbrella mode run the work in that repo's folder and commit there too. With P8, before handing off read the runbook `docs/runbooks/trunk.md`; the root session opens a side branch with `trunk.sh open`, `cd`s into its worktree to run it, and ends with `trunk.sh merge` instead of the finishing menu. Per feature: gate green → commit (rules below), with the plan checkbox in the same commit (umbrella: different git, P8: different worktree, so tick it on main, where the plan lives, with `docs: check off <task>`).

## Commit rules

- **Unit = one concern.** One concern over N files is 1 commit; two concerns mixed in one file → split with `git add -p` into 2 commits. No "WIP", "misc" or "fix stuff".
- **Format = conventional commit** `<type>(<scope>): <summary>` — scope is a boundary, repo folder or area (`design`, `api`, `ci`, …); the summary is English, imperative, at most 72 characters; the body gives the *why* in a sentence or two (only when needed). `Ref:` goes in the body.
- **When = right after the gate goes green.** Never commit with lint, types or tests red. A docs-only commit (`docs:`) needs only `check-docs.sh` (if there is one).
- **Bundling:** one commit per feature — `feat(<boundary>): implement X` carries the tests, the implementation and the plan checkbox (with P8, a separate `docs: check off` on main); do not split it per step. Do not slip other concerns in.
- **Umbrella mode:** code in its repo, docs in the umbrella — a task across two repos gets one commit per repo. Before committing, check with `git -C <repo> status` that no stray files leaked in.
- **Report format:** after committing, show the `<short sha> <message>` list, and if uncommitted changes remain, say why. Never push, rebase or force anything.

## Common mistakes

| Mistake | Fix |
|---|---|
| Applying web-only rules (URLs, rem, CSS variables) to an app | The per-form table in `reference/client-forms.md` |
| Skipping the design stage and starting from framework default styles | With a UI, stage 3 is required; no components before the token lock |
| Leaving generator boilerplate behind | Confirm 4-5 removed it all: `rg -n 'system-ui\|gradient\|lorem' src app` finds 0 |
