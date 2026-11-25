## Docs — what goes where
| Information | Where | How |
|---|---|---|
| Rules · commands · boundaries · terms | `CLAUDE.md` · `CONTEXT.md` | edit in place |
| Hard-to-reverse decisions | `docs/adr/` | new file; a reversal is a new ADR |
| Design of one piece of work | `docs/specs/` | a new file per piece, frozen once approved |
| Running one piece of work | `docs/plans/` | one file per piece, a checklist |
| Work not finished this time | `docs/ledger.md` | one row per item |
| Where to resume now | `docs/plans/handoff.md` | overwrite; work in progress only as a plan path |
| Operating facts that do not change | `docs/plans/status.md` | edit in place, each line with source · date checked |
| Procedures | `docs/runbooks/` | edit in place |
| Closed specs · plans, research nothing outside archive points at | `docs/archive/` | `git mv` at release (after the closing commit) |
| Finished history | git log | not moved |
| Preferences · feedback | auto memory | no project facts · state |

- **Size**: state it in one line at the start. If unsure, size up; if it grows, stop and size up. S (one session, no new decision): test → commit. M (several tasks, no new decision): plan → TDD → review per task. L (a boundary · data · auth · money · security decision changes): spec → M, plus an ADR if hard to reverse. Before declaring done, check with a real call.
- **Kind**: bug `DEF-n`: a failing regression test first. Refactor `DEBT-n`: green without changing existing assertions (no tests → write them first); L if a boundary changes. Security `SEC-n`: audits per `docs/runbooks/security-levels.md` ①. Feature `REQ-n`: if a trust boundary changes, security checkpoint 4.
- **Head**: within the first 15 lines of a spec · plan, `> Status: draft|approved|active|done|dropped|superseded (date, …)`. At the first task set `active` and add `> Resume at: task · step · one line`, updated when a task ends or the session is cut. On resuming, compare with the checkboxes and `git log --grep`.
- **Closing** in one commit: no `- [ ]` left (a step not taken: `- [-] reason`) · `done (date, hash)` (the spec too) · deferred items into the ledger · removed from the handoff. A reversed spec · ADR gets `superseded (date, → path)`. A closed row · confirmed fact reopens only by naming its evidence and what differs.
- **Commits**: one per feature (tests · implementation · plan checkboxes together, not split per step). If the plan is in another git · worktree, checkboxes go in a `docs: check off <task>` commit when the task ends. In the body, `Ref: <plan topic> T1 T2` or `Ref: DEF-n`. The hash at the end of a task title is written in the closing commit, and a plan's or ledger row's `done` hash is only a commit on main. No hashes in handoff · rule · spec bodies. Tasks are never renumbered. Review fixes are follow-up commits, never squashed.
- `.superpowers/` is temporary. What should stay goes into the plan · ledger.
