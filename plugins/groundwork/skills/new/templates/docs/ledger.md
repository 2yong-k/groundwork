# {{project_name}} ledger
Status: in use
Date: YYYY-MM-DD

A table that numbers defects · UX · requests · security · debt. **Do not write the current situation here** — what to do now goes in the handoff (`docs/plans/handoff.md`). Get the open rows with `rg '^\| [A-Z]+-[0-9]+ .*\| (open|active|verifying|on hold)[^|]*\|$' docs/ledger.md`, and do not copy them into the handoff.

- A number once used is never reused. Next number = the largest number in the ledger · `docs/archive/` · the commit bodies of every branch (`Ref:` written before the ledger, and those of side branches not merged yet) + 1: `{ rg -oIN 'DEF-[0-9]+' docs/ledger.md docs/archive/; git log --all --format=%B | rg -o 'DEF-[0-9]+'; } | sort -t- -k2 -n | tail -1` (the same for UX · REQ · SEC · DEBT).
- Row = current state + evidence pointer (commit sha · spec §) only. Do not append the fix history to the row — the history is in git log. A row is 300 characters or less, and the gate checks it.
- Finished rows (`done` · `dropped`) move per bundle (release) to `docs/archive/ledger-closed-YYYY-MM.md`. The IDs stay the same, so `rg` finds them. Closed specs · plans and research move in the same commit (the docs table of `CLAUDE.md`).

## Numbering
- `DEF-n` defect: behavior differs from what is expected. Write the symptom, cause and evidence (how to reproduce · logs · commits).
- `UX-n` screen · usability: behavior is right, but it is awkward to use or looks bad.
- `REQ-n` request: a new feature or a policy change. Before approval, the priority stays 'tbd'.
- `SEC-n` security: an open item from an audit · check. Write the source (`/groundwork:security-audit` run path · checkpoint).
- `DEBT-n` debt: behavior is right, but the structure needs fixing. Write why it is deferred.
- Priority: `P0` blocked now · `P1` this bundle · `P2` next bundle · `P3` when there is room · `tbd`.
- Status: `open` · `active` · `verifying` · `done` · `on hold` · `dropped` — markers that the docs gate and the open-row query read, so they stay English in any docs language. The status cell holds only one current state and its date. For `done`, also write the commit hash that went into main, the environment checked (`local` · `staging` · `prod`) · the kind of evidence (`measured` · `config value` · `code reading`): `done (11-02, 34b1f42, prod measured)` (an umbrella adds the repo, like `be@34b1f42`). If only some environments are closed, write it so the remaining ones show: `verifying (11-10, staging measured)`.

## Defects
| id | Area | Symptom · cause · evidence | Priority | Status (date) |
|---|---|---|---|---|
| DEF-n | {{area}} | Symptom: … / Cause: … / Evidence: … (sha · spec §) | P1 | open (YYYY-MM-DD) |

## UX
| id | Area | Symptom · cause · evidence | Priority | Status (date) |
|---|---|---|---|---|
| UX-n | {{area}} | Symptom: … / Cause: … / Evidence: … (sha · spec §) | P2 | open (YYYY-MM-DD) |

## Requests
| id | Area | Request · reason · evidence | Priority | Status (date) |
|---|---|---|---|---|
| REQ-n | {{area}} | Request: … / Reason: … / Evidence: … (spec §) | tbd | open (YYYY-MM-DD) |

## Security
| id | Area | Content · source · evidence | Priority | Status (date) |
|---|---|---|---|---|
| SEC-n | {{area}} | Content: … / Source: … (audit run · checkpoint) / Evidence: … (sha · spec §) | P1 | open (YYYY-MM-DD) |

## Debt
| id | Area | Content · reason · evidence | Priority | Status (date) |
|---|---|---|---|---|
| DEBT-n | {{area}} | Content: … / Reason: … / Evidence: … (sha · spec §) | P3 | open (YYYY-MM-DD) |
