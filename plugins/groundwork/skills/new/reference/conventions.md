# Conventions

Rules /groundwork:new follows at every stage, next to its stage files. SKILL.md and the other reference files point at these sections by name.

## Interview

- Ask one question per message, and only one. Do not tack a second ask onto the end of it.
- Every question comes with your recommended answer and the reason for it, so the user can take it as is or push back on the reason.
- Exception (SKILL.md principle ②): a module message or baseline message puts its numbered questions, each with a recommended answer and reason, in one message and asks "as recommended, or just the numbers to change". After that, only the changed numbers are asked, one question per message, until each is settled.

## Glossary and ADRs

**Glossary.** Domain terms live in `CONTEXT.md` under `## Glossary`, one line each:

`**Term** — definition. Avoid: <synonyms>`

The signal to write a term down is the moment the same thing goes by two names: settle on one, list the other after `Avoid:`, and use only the settled name from then on.

**ADRs.** A decision that is hard to reverse goes in `docs/adr/NNNN-<slug>.md`, where `NNNN` is the next free four-digit number. An ADR has these sections:

- `## Context` — the situation and what forces a decision.
- `## Decision` — what was decided, stated so it can be checked.
- `## Consequences` — what gets easier, what gets harder, what is now ruled out.
- `## How to verify` — the test, gate or command that shows the decision still holds.

An ADR that has a template in `templates/adr/` follows that template instead.

## Engineering rules

**Principles**
- Make the smallest change that solves the real problem. Deleting beats editing, and editing beats adding.
- Before writing new code, climb the ladder and stop at the first rung that holds: not needed → skip it (YAGNI); already in this codebase → reuse it; the standard library does it → use that; a platform feature does it → use that; an installed dependency does it → use that; only then write the least code that works.
- Never cut corners on security, data-loss handling, validation at trust boundaries or accessibility.
- Read before you judge: never guess about code you have not read or intent nobody stated. Read first, then offer concrete options with a recommendation.
- Keep to the scope: leave unrelated code as it is, and do no rewrites on the side.

**Code**
- TypeScript: `strict` mode; never `any`, and never an `unknown` left unnarrowed; discriminated unions for variants; validate data where it crosses a boundary (for example with Zod).
- Python: strict type hints everywhere; ruff for lint and format; pytest for tests.
- Fail fast with typed errors, match exhaustively and keep null-safety strict. At I/O boundaries, handle partial failure and make operations idempotent.
- Tests cover contracts, boundaries and error semantics.

**Git**
- Conventional commits: `<type>[(scope)][!]: <description>`, with type one of feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert.
- One concern per commit: one concern across N files is one commit, not N. No WIP commits and no commits that mix concerns.
- Tests pass before every commit.

**UI**
- Use design-system tokens, never hardcoded values.
- Avoid AI-default looks: purple-blue or purple-pink palettes, gradients on buttons or titles, `transition: all`, `font-family: system-ui`.

## Subagent models

When work goes to subagents, pick each one's model by risk instead of reusing the main session's model.

- **Opus** — code that moves money or settles orders, auth, secrets, migrations, on-chain calls, cross-cutting refactors, and the reviews of any of these.
- **Sonnet** — low-risk or mechanical work: docs and comments, tests that follow an existing pattern, read-only research and code search.
- **Haiku** — chores that need no judgement: listing, counting, extracting fields.
- Unsure which → Opus.
