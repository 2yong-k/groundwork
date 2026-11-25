# Side branch · merge · milestone runbook

The procedure for opening a side branch (one plan that changes code), working inside it, merging it, tidying up and reaching a milestone. The command is `bash scripts/trunk.sh` (`help` shows how to use it). `<name>` is the side branch name.

## 0. This runbook comes first

- This runbook and the side-branch line of `CLAUDE.md` come before the instructions of the superpowers skills (using-git-worktrees · executing-plans · subagent-driven-development · finishing-a-development-branch · requesting-code-review). If a skill says otherwise, follow this one.
- What it overrides is in the sections of this document: lockfile install, the plan's absolute path and checkboxes (3), the review standard and grading rule (4), `merge` instead of the finishing menu (5).
- The scripts do not edit docs and do not push. Docs are edited by the session on main; push and deploy are done by you.
- One exception: the hotfix branch of section 5 of the release runbook (`docs/runbooks/release.md`) must branch from the prod tag, so it does not use `open` · `merge`; it is made and merged as that runbook says. After merging, look at the map with `bash scripts/trunk.sh`.

## 1. Where sessions sit

- Open sessions at the root. The root is the umbrella folder for an umbrella project and the repo folder for a single repo. Do not open a session in a side branch folder (under `.worktrees/`).
- The root session runs `open`, does `cd` into the side branch folder to work (with several repos, it moves between the repo worktrees with `cd`), and comes back to the root to edit docs or merge. For parallel work, open more sessions at the root. Do not use EnterWorktree.
- Run `open` · `merge` · `tidy` at the root without `scripts/heavy.sh`. For a refusal (`Refused: …`, exit 2), the output says what to do.

## 2. Opening a side branch

- The side branch unit is one plan that changes code. A small fix (no plan) and a docs or research plan are done on main without a side branch. A security check or full check only reads on main, and the fixes from it are gathered into one plan and done on its side branch.
- Put the side-branch line in the first 15 lines of the plan head: `> Side branch: <name> · Milestone: <vX.Y.0>`. If the milestone has no name yet, it is `Milestone: tbd`. Write it on main when writing the plan. In an umbrella, also write the repos it touches with `> scope: <unit>+<unit>`.
- The side branch name is the plan file name without the date and `.md`, used only once in the project. If it clashes, add `-2` to the plan file name (`2026-12-01-auth-2.md` is `auth-2`).
- Run `bash scripts/trunk.sh open <name>` at the root, and read the entry screen before starting work. If the plan redoes a closed ledger row, first give what differs from the evidence in the status board · ledger.
- A stop is `Stop: <key>: <reason>`, with exit 1. For a stop not in the table, follow what to do after the `—` in the output; if no action is written (`something is already at the side branch spot` · `could not find the worktree record`, etc.), the session does not delete or move anything and asks you.

| Reason | What to do |
|---|---|
| `no plan` · `two or more plans` · `plan closed` · `name differs from the plan topic` · `scope unit …` | Fix the side-branch line of the plan head (the name is the topic of the plan file name) or `scope` (the unit names of the repo map, `all` for every repo). The side branch of a closed plan is not opened |
| `not a symlink` | Move the edited lines of the copy to the canonical file as in 3, and turn it back into a link |
| `same-named branch that is not a side branch` | If the output gives a way out, do exactly that and run again; if not, you decide |
| `.worktrees/ not ignored` | On main, add a `.worktrees/` line to the root `.gitignore` (in an umbrella, the umbrella docs git) with a path-scoped commit (`git add .gitignore && git commit -m "chore: ignore .worktrees/" -- .gitignore`), and run `open` again |
| `<name>/… branches` | A branch under it exists, so the `<name>` branch cannot be made. The session asks you |

- A dead `open` picks up where it stopped when run again. If a recent-activity warning shows, first check that it does not overlap with that session.
- In an umbrella, when `Note:` shows, look, together with the plan's `scope`, at whether that sibling repo should also be opened on this side branch (10).
- Setting the plan status to `active` is done by the session on main.

## 3. Working inside

- After `cd` into the side branch worktree, install first, with the lockfile command exactly (`pnpm install --frozen-lockfile` in a pnpm repo). Do not use the `npm install` of using-git-worktrees step 2 (it makes a `package-lock.json` in a pnpm repo).
- `open` copies from the main checkout only the ignored `.env*` files the worktree lacks (the `env copied:` line, which prints paths only; `.env.example` · `.env.production*` are left out). If you changed the file on main, delete the side branch's copy and run `open` again. If a copy differs from main, `tidy` keeps that side branch.
- After `cd` into an umbrella repo worktree, read that repo's `CLAUDE.md` first.
- Before committing, check that `git branch --show-current` is the side branch name. After a trip to the root, or after Claude Code reverted the `cd`, commits land on main, and the scripts cannot stop this.
- Run git as `git -C <side branch absolute path> …`, not chained on one line like `cd <side branch> && git …`. Claude Code puts git chained after `cd` up for approval regardless of the allowlist.
- Code is committed in the side branch worktree. Docs (`docs/` · `CLAUDE.md` · `CONTEXT.md`: specs, plan checkboxes and `Resume at`, the ledger, the status board, the handoff, ADRs, runbooks) are not edited on the side branch.
- Read and edit docs by the main checkout's absolute path. The `docs/` inside a side branch is a stale copy. Pass the execution skill the plan absolute path `open` printed. Passed by another path, a separate workspace appears and finished tasks get done again.
- Docs several sessions edit together, such as the ledger · status board, are reread, edited and committed within one tool call. That call starts with `test -z "$(git status --porcelain -- <file>)"` (as a condition, not just printed output). If it fails, another session left an edit half done, so do not overwrite it or commit it along with the rest; stop and ask you. Docs commits are path-scoped (`git commit -m … -- <file>`).
- Plan checkboxes are not ticked by the execution skill. When a task ends, tick it once on main with a `docs: check off <task>` commit.
- If the side branch needs new commits from main, run `git merge main` in the side branch worktree. No rebase. If it was done after the review mark, the mark is void (4).
- Only one main session writes the handoff. Side branch sessions write their position only in the plan head's `Resume at`.
- `CLAUDE.md` too is edited at its canonical copy on the main side. A single repo adds to the main checkout's `CLAUDE.md` with a `docs:` commit. An umbrella edits it by the canonical path `<umbrella>-<unit>/CLAUDE.md` (Edit cannot write through the symlink in a worktree). Do not swap it in with `mv`.
- If parallel sessions take the same next number (ledger · ADR) and the gate catches it, renumber the later one.
- Execution skills (subagent-driven-development · executing-plans) see only one repo. For a side branch across several repos, `cd` into a repo worktree and call them with only that repo's tasks. The order between repos is set by the plan.
- Do not push a side branch. CI runs only on pushes to main and PRs that target main.
- Do not apply migrations to the shared DB (staging) from a side branch. The shared DB's migration history must match main. On a side branch, only make and commit the files; run `db:push` (`make db-push` for uv) after merging, in the main checkout. Applying to a local DB is fine. `db:push` stops outside the main checkout. If the side branch needs code that uses the new schema, it is one of two: finish a task that holds only the migration first, ask you for a partial merge, commit the apply · type generation on main, then `git merge main` on the side branch; or apply to a local DB and generate types against local (Supabase `gen types --local`). If an apply stops on a migration version that exists only on the remote, another side branch applied it first. Do not repair (the next apply's `CREATE` fails); tell you, and once that migration comes into main, apply it again on main.

## 4. Review mark and waits

- The end review is done by a reviewer subagent. For each repo the range is from the local `git merge-base main HEAD` to the side branch tip. `origin/main` is not used: Claude does not push, so it is stale. With several repos, it is done per repo. A partial merge uses the same range.
- Clean means: every Critical · Important of the end review and re-reviews is fixed. The grade is the higher of the reviewer's grade and Claude's regrade. Only findings whose higher grade is Critical · Important block. Ones left unfixed as Ruling · parked · Deferred also block at that grade. Minor does not block. The reviewer's grade is advice only.
- If clean, write the review mark at the end of the plan head's side-branch line on main, commit, then run `merge`. Its shape is `· Review: <side branch tip, 12 characters>` (`git rev-parse --short=12 HEAD` in the repo worktree). An umbrella writes `· Review: be@<12 characters> fe@<12 characters>`, only for the repos with side branch commits.
- Write the mark after the review and the fixes are all done: for subagent-driven-development, after the fix wave and re-review; for executing-plans, when the fix step is over and everything is green. There is one mark per line, so writing it again replaces it.
- If the side branch tip changed after the mark (merging main included), the mark is void. Per repo, re-review only `git log --first-parent -p --remerge-diff <mark>..<tip>` and write a new mark. Do not use `--cc`: it hides conflicts resolved as ours. A repo with no hash in the mark is reviewed in full, from `git merge-base main <name>` to the tip.
- If not clean, do not write the mark. Add `· Waiting: review findings` to the side-branch line (`merge` stops), leave the execution skill's workspace, and report the remaining findings to you. If you clearly say to merge as is, write the mark with the tip hash at that time (delete `Waiting`), and record that statement in a ledger row (usually `DEBT-n`) for each remaining finding.
- Only when subagents cannot be used, do a self review, and only then add `· Waiting: self review`. When you confirm it, replace it with the mark.

## 5. Merging

- At the root, call `bash scripts/trunk.sh merge <name>` as a background run of the Bash tool, and when it ends, read the tail of the log it printed (`Log: <path>`, in the root's `.superpowers/trunk/logs/`). Install · `verify` · e2e take long, and this keeps them from being cut off by the command time limit. The session does not show the finishing menu and does not ask you before merging.
- Exit codes: 0 done (merged, or `Already all in`) · 1 stopped on a check (`No commits to merge` · `<N> commit(s) left, plan not closed` included) · 2 usage error or refusal to run · 3 half merged (7). main moves only at the last raise.
- A stop is `Stop: <key>: <reason>`. For a stop not in the table, follow what to do after the `—` in the output; if it stops on the review mark, write a new mark as in 4.

| Reason | What to do |
|---|---|
| `no plan` · `two or more plans` | Fix the side-branch line of the plan head |
| `plan closed` | The side branch of a `dropped` · `superseded` plan is not merged. Ask you whether to drop it or reopen the plan |
| `same-named branch that is not a side branch` | Do as in the same row of 2 (if `rerun open to resume`, start from `open`) |
| `waits for the next milestone` · `not in the milestone table` | Wait until that milestone is reached (6). A milestone not in the table is added to the status board (9) |
| `worktree <condition>` | Commit or clean up in the side branch worktree, then run again |
| `CLAUDE.md not a symlink` · `docs only main edits` | Move them to the canonical copy and turn it back as in 3 |
| `no verify` | Make `verify` in the repo (a pnpm script or Makefile target: one-line gate + build + e2e). |
| `this side branch broke <repo>` | Fix it on the side branch to fit that repo |

- If it breaks only on a conflict or in the merged combination, make the same combination in the side branch worktree with `git merge main` and fix it there (conflict resolution by Opus). The side branch tip changes, so write a new mark.
- Even when stopped, do not put things on main with a hand `git merge` · cherry-pick. Side branch commits go into main only through `merge`.
- Do not trust the failure · breakage report of a `merge` cut off with Ctrl-C; run `merge` again.
- Close the side branch plan after `merge` ends with 0. Even if the docs gate gives a WARN to close it because its open tasks are 0, do not close it first.
- When the final merge ends with 0, close the plan on main. The hash of `done (date, hash)` is, for each repo that has `chore(trunk): merge <name>` commits on main, the last of them (`git -C <repo> log --first-parent -1 --format=%h --grep='^chore(trunk): merge <name>$' main`). An umbrella writes only those repos, as `<repo>@<hash>`. At the end of each task title, write that task's side branch commit hash wrapped as `` `hash` `` (the docs gate looks up only wrapped hashes in git). Put the ledger rows and the handoff in the same commit, and run `bash scripts/trunk.sh tidy` (8).

## 6. Partial merge · on hold · next milestone

- A partial merge (`merge <name> --partial`) is done only when you want to ship the part done so far first. Every repo to merge is merged together, through the same checks and review mark. The side branch and plan stay open, and it runs even with open `- [ ]`.
- To hold off merging even when finished, add `· On hold: <reason>` to the side-branch line, because what is merged ships in the next tag and deploys automatically to staging.
- A side branch aimed at a milestone later than the earliest `open` one is not merged before that milestone is reached.

## 7. Half merged

- In an umbrella, when only some repos got onto main, `Half merged: <raised> raised, <not raised> not raised` shows, with exit 3. The plan is not closed.
- Repos already raised are not rolled back. No reset of any kind.
- In the main checkout of a repo not raised, look at `git status`. If a hook refused, side branch files stay staged.
- Fix the cause (hook refusal · another session's `index.lock` · main moved), then run `merge <name>` again.

## 8. Tidying and dropping

- After closing the plan, run `bash scripts/trunk.sh tidy` at the root. Side branches that can be removed are removed without asking (`Removed: <name>`), and the rest are kept with a reason (`Kept: <name> — <reason>`, exit 0).
- After removing the reason, run `tidy` again. Do not delete directly with `git worktree remove --force` or `git branch -D`.
- Dropping a branch or worktree with unmerged commits is your call. Claude only shows it on the map and asks; what you decide to drop, you do yourself or tell it to do.
- A stash that cannot be tied to a branch (`(no branch)` · `autostash`) blocks every side branch of that repo. Report it by its stash commit hash; whether to move it with `git stash branch` or drop it is your call.

## 9. Milestones and tags

- A milestone is a minor version (`vX.Y.0`), where one bundle of work you named ends. The list and the cell shapes are in the `## Milestones` table of the status board `docs/plans/status.md`. When the goal or scope changes, edit that line.
- When all side branches of the milestone are in main and staging QA is done, change the status cell to `reached (today's date)` and the QA cell to `done (date, evidence)`, propose a name for the next milestone and ask you. You name the milestones. Once settled, add a `| v0.2.0 | name · goal | open | waiting |` line to the table.
- When a milestone is reached, make one more tidy commit: move the ledger's finished rows · closed specs · plans · research nothing outside `docs/archive/` points at into `docs/archive/` (`git mv`), and check for each line of the `CLAUDE.md` Mistakes log whether its trap is still there.
- A plan opened before the name is settled stays `Milestone: tbd`. It counts as the earliest `open` milestone, or as the next milestone if none is open.
- Claude tags locally when you say to: `git tag -a vX.Y.0 -m "…"`. A milestone gets the same `vX.Y.0` in every repo that ships prod by tag; the `vX.Y.z` between milestones are tagged per repo. You push the tags.
- Open the map (`bash scripts/trunk.sh map`) when you ask to see it and when a milestone is reached. At session start and when opening a side branch, read the short map with no argument.
- Status board `## Facts` lines · closed ledger rows · a milestone's QA line are overturned only after first giving the evidence and what differs, by the status board's reopening rule.

## 10. Several repos

- An umbrella's side branch folder holds only the side branch repos, so checks that read a sibling repo (the token check `sync-tokens.sh --check ../<umbrella>-fe/…`) may `SKIP`. Merge ② makes the final call.
- Token plan rule: a plan that changes fe's `design/tokens.json` puts every UI repo (the repos with `scripts/sync-tokens.sh`) in `scope`, with a task on the same side branch that re-syncs them with `sync-tokens.sh`.
- `verify` runs per repo and does not start the merged be and fe together. So a plan across several repos must include, as a task, tests that check the contract between the repos (API response shape · events · environment variable names) in the `check` of both repos.
- A side branch repo with 0 side branch commits is not merged (`skipped (0 side branch commits)`), but its worktree conditions are checked all the same.

## 11. Report format

The merge report goes to you in five lines. Lines 1–4 copy the script's output lines as they are.
1. The commits merged per repo (`<key>: <N> commit(s)` · `<key>: skipped (0 side branch commits)`).
2. The `verify` result and time (the `②:` line; in an umbrella, the `check` of the other repos too; the `verify reused` · `old heavy.sh` lines if present).
3. `<key>: main <before, 12 characters>..<after, 12 characters>`.
4. The `Next:` line.
5. `push stays with the user`.

Then attach the map's text output (the short version). If it stopped or half merged, start the report with that line (`Stop: …` · `Half merged: …`) and what to do.
