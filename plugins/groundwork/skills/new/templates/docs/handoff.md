# {{project_name}} handoff
> First prompt: `Session {{session_number}}. Read docs/plans/handoff.md, ask me about section 3 first, then continue from '1. Next'.`

A document for ending a session so the next session can pick it up. Before each commit, run the carry-over check: every ID in the previous version appears in the new one — open items in section 4, closed ones in section 5 (`git show HEAD:docs/plans/handoff.md` gives the previous version). **Only what comes next, 10KB or less.** Finished work goes in the ledger · git, facts that stay the same across sessions in the status board (`docs/plans/status.md`), rules · lessons in CLAUDE.md. The current state lives only in this document. For work in progress write only the plan path; the position goes in the plan head's `Resume at`. Overwrite it at the end of each big step.

## 0. Now (10 lines or less)
- main HEAD · WIP · open side branches: `bash scripts/trunk.sh` (do not copy them here)

## 1. Next (in order)
1. {{next_item}} — Start at: {{plan_path}} (the position is in the plan head's `Resume at`)
<!-- Next goal: {{next_goal}} -->

## 2. Scheduled (a new session re-arms the schedules)
<!-- When the date comes, check without asking and report. Something watched with no schedule goes on an 'ongoing' line; once it passes its threshold, move it to the ledger with a number. -->
- YYYY-MM-DD HH:MM TZ — {{what_to_check}} · {{where}}
- ongoing — {{signal}} (threshold {{threshold}}) · next check YYYY-MM-DD

## 3. For you (decisions · things to do yourself)
<!-- Split by when (now · at a time · after a signal) and number the items (3-1 …). An item to do yourself gives why · what to do (a long command as `! sh <path>`) · how to tell it worked · what to say when done (`3-1 done` / `3-1 blocked: <screen text>`). Screen QA goes down to the account · tab · exact input · what should show · cleanup steps, and example input does not lean on world facts nobody checked (no wording with a date baked in). External waits (legal · partners · keys) give the last contact date and "what to do when the answer comes". -->
3-1. {{question_or_action}} — what it is (not a short name; where it runs · who runs it): … · recommended: … (reason: …)

## 4. Open items (one per line)
<!-- Only what is not in the ledger, as [short name] one-line summary → owner doc §. Open ledger rows are not copied here; get them with rg '^\| [A-Z]+-[0-9]+ .*\| (open|active|verifying|on hold)[^|]*\|$' docs/ledger.md. Do not point at an earlier version (no "the rest is in handoff N"). Parallel sessions write only in the plan head's `Resume at`; one main session merges them into this document. -->

## 5. Closed this session
<!-- IDs only -->
