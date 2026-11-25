# {{project_name}} status board

10KB or less. Only what stays the same across sessions. The current state (work in progress · what comes next) belongs to `docs/plans/handoff.md`, and procedures go in `docs/runbooks/`. A session reads this document and `bash scripts/trunk.sh` before starting work.

## Milestones

| Milestone | Name · goal | Status | staging QA |
|---|---|---|---|
| v0.1.0 | {{first_milestone}} | open | waiting |

- A milestone is one minor version (`vX.Y.0`). Its name · goal is the bundle of work you named; when the goal or scope changes, edit this line.
- Status: `open` · `reached (YYYY-MM-DD)`. The map's calendar math reads this shape, so dates are written `YYYY-MM-DD`. The source of truth for a milestone's date is `reached (date)`, because some repos use no tags.
- staging QA: `waiting` · `done (date, evidence)`.
- Tag dates · side branches shipped in a milestone · missing commits are not written here. The map (`bash scripts/trunk.sh`) computes them from git. The side branches shipped in a reached milestone show under that milestone in `status` and `map`.

## Facts

Write the current values that stay the same across sessions (addresses · accounts · version policy · environment cautions). The line shape is `- <fact> — source: <path · command> · Checked: YYYY-MM-DD`. Values git computes, such as tags · deploy hashes · branches, are not written.

Checks the agent cannot do (screens behind a login · staging behind a VPN) are written as 'for a person', and a private staging gets how to reach it plus a one-line command that checks it is reachable (a timeout means the connection is down, not something to change in code or the environment). For values the agent cannot read, write that an empty answer does not mean 'none'.

To reopen a confirmed fact, first give that line's evidence and what differs (a new commit · another environment · new evidence). If nothing differs, do not reopen it. When fixing a line, do not delete it; replace it with the new evidence and check date.
