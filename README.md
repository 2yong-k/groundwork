# groundwork

A Claude Code plugin for the first day of a software project. Run `/groundwork:new` in an empty folder and Claude interviews you, writes the project's documents from your answers, builds a working skeleton, and then proposes the first task. Run it in a project that already exists and it adds the same rules and checks without deleting anything (the overlay).

It is for developers who start a project with Claude Code and want decisions, rules and checks written down from the beginning, so later sessions follow them. It runs only when you type the slash command. Typing it again in a half-finished folder resumes from the stage where it stopped.

## Quick start

Install it in Claude Code:

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin marketplace add 2yong-k/claude-plugins
/plugin install groundwork@2yong-k
```

groundwork depends on superpowers (see [Dependency](#dependency)); Claude Code installs it for you from the `claude-plugins-official` marketplace. The first line adds that marketplace: without it, groundwork installs but fails to load because superpowers is missing. Skip the line if you have already added it.

Then make an empty folder, start Claude Code in it, and type the command with a one-line purpose:

```
/groundwork:new a shopping list web app the family shares
```

What to expect:

- It asks one question per message, each with its recommended answer and the reason. The purpose you typed answers the first question.
- It interviews you about the product (users, core scenarios, what is out of scope, done criteria), then about the skeleton (stack, storage, auth, boundaries). With a UI, it adds a design interview that ends in locked design tokens.
- It writes the documents from your answers and asks for your approval at the end of each stage. It creates no project files before that approval, except `CONTEXT.md` and `docs/adr/` during the interviews.
- It builds the skeleton and runs the gate (defined below) until it is green, then commits. It never pushes.
- It proposes one to three first tasks from the plan and waits for your pick.

## What it leaves in your project

A gate is one command, `pnpm check` or `make check`, that runs lint, type checks, tests and the project's other checks. The same command runs in CI. Paths are relative to the project root; the full list is the Output map in `plugins/groundwork/skills/new/reference/baseline-scaffold.md`.

- `CLAUDE.md`: the project's rules on one screen. State and history stay in docs and git.
- `CONTEXT.md`: the product summary, the glossary and the project profile.
- `docs/adr/`: one decision record per hard-to-reverse choice.
- `docs/specs/` and `docs/plans/`: the design spec and the implementation plan, each with a status that the docs gate checks.
- `docs/runbooks/`: incident response, secret rotation, release (for projects that deploy), and `security-levels.md`, which lists nine checkpoints and says when to run `/groundwork:security-audit`.
- `scripts/`: the gate scripts, for example the docs check and, with a UI, the token, contrast and banned-pattern checks.
- `.githooks/pre-commit`: scans staged changes for secrets with gitleaks before each commit.
- `.github/workflows/` and `.gitleaks.toml`: CI with the required check job, plus secret scanning.
- `.claude/settings.json`: deny rules for commands a person should run, such as deploys and secret writes.
- With a UI: `DESIGN.md`, `design/tokens.json` (the token source) and `docs/design/directions.html`.
- Only for projects that switch the matching module on: `docs/vendors.md` (external dependencies) and, for a multi-week project, `docs/ledger.md`, `docs/plans/handoff.md`, `docs/plans/status.md`, `docs/runbooks/trunk.md` and `scripts/trunk.sh`.

## Requirements

- Tested on Claude Code 2.1.327. The plugin uses plugin `userConfig`, `${CLAUDE_SKILL_DIR}` and plugin `dependencies`.
- The turn that `/groundwork:new` starts runs on Opus at xhigh effort (its `SKILL.md` sets `model: opus` and `effort: xhigh`; the `CLAUDE_CODE_EFFORT_LEVEL` variable and an effort cap take precedence). Later turns, the rest of the interview included, run on your session's model and effort, so set the session to Opus at high effort or above with `/model` and `/effort`.
- With an API key, turns on Opus are billed at Opus rates; on a subscription plan they count as Opus usage.
- macOS or Linux; on Windows, use WSL.
- `git`, `node` and `bash` on the PATH (the gates and the security-audit validators use them).
- Projects it scaffolds also use gitleaks for the commit hook (`/groundwork:new` asks you to install it when it is missing) and ripgrep (`rg`) for some gates.

## Language

The install dialog asks for a language (default English). Change it later with `/config`, or with `/plugin configure groundwork@2yong-k`. Examples: English, Korean, Japanese.

The setting decides the language of the conversation and of every document groundwork writes from your answers: `CONTEXT.md`, ADRs, specs, plans, the handoff and ledger rows, template prose included. A project's `CLAUDE.md` line `- Docs language: <lang>` wins over the setting; if the two differ, groundwork says so once.

These stay English whatever the setting: files copied as they are (runbooks, gates, the status board, security levels), the markers that gates parse (`Status:`, `Resume at:`, `## Project profile`, `Milestone:`, and so on), code, identifiers and commit messages.

## Update

Either turn on auto-update: `/plugin` → Marketplaces → 2yong-k → Enable auto-update. Or update by hand:

```
claude plugin update groundwork@2yong-k
```

Then run `/reload-plugins` in the open session (or restart it) to load the new version.

## How it works

| Stage | What it does | Rules |
|---|---|---|
| 0 State check | Reads the folder's artifacts to tell which stage it is in and reports the resume point. After the first task it resumes from the handoff and the active plan | `SKILL.md` |
| Overlay | For an existing project that `/groundwork:new` did not start (single repo or umbrella): read-only analysis, one question, then an overlay plan (move the docs, switch the gates on behind a violation baseline, add the missing baseline items) | `reference/overlay.md` · `templates/gates/baseline.sh` |
| 1 Discovery interview | What are we building, written to `CONTEXT.md` | `SKILL.md` |
| 2 Skeleton interview | Project profile check, baseline, the modules that are on, ADRs, then the spec and plan | `reference/profile.md` · `baseline.md` · `client-forms.md` · `modules/P1.md`–`P9.md` |
| 3 Design interview | Only when there is a UI. A direction sheet with three directions, then a token lock | `reference/design-interview.md` |
| 4 Scaffold | Every gate green on an empty skeleton, then the first commit | `reference/baseline.md` · `baseline-scaffold.md` · `templates/` |
| 5 First task | Proposes one to three first tasks from the plan and waits for your pick | `SKILL.md` |

All paths in the Rules column are relative to `plugins/groundwork/skills/new/`.

Modules apply per project profile: the profile check decides which are on. The baseline applies to every project, as a subset per project form.

- **Modules:** P1 numbers and units, P2 multiple instances and async, P3 public surface, P4 AI pipeline, P5 i18n and URLs, P6 multiple apps, P7 external dependencies, P8 heavy operations kit, P9 money-moving keys. A multi-week project (P8) opens one side branch per plan and works in parallel.
- **Baseline:** B1 environment separation, B2 secrets, B3 strictness, B4 CI, B5 reads and failures, B6 minimum observability, B7 release model, B8 docs, B9 way of working, B10 supply chain, B11 detection and response, B12 hardening.
- **Forms:** single repo or umbrella (multi-repo); web, native app or webview shell.

## Skills

- `/groundwork:new [purpose]`: the kickoff described above. Typed by you only; the model never invokes it on its own.
- `/groundwork:security-audit`: a security review of a codebase, from a focused review up to a full audit. Typed by you only. The project's `security-levels.md` says at which points (first beta, real money, a trust-boundary change, and so on) to run it.

There is also a `reference` skill that is not user-invocable; it only gives the paths of the modules and spec sections to a project's `CLAUDE.md` or spec that points at them.

## Dependency

superpowers by Jesse Vincent (MIT), installed as `superpowers@claude-plugins-official`. Tested with 7.0.2. If it is missing, `/groundwork:new` stops and asks you to run `/plugin install superpowers@claude-plugins-official`.

## License

[MIT](LICENSE)
