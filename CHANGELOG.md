# Changelog

## 1.0.0 — 2026-11-25

groundwork is a Claude Code plugin for the first day of a software project.

- `/groundwork:new`: in an empty folder, Claude interviews you, writes the project's documents from your answers, builds a working skeleton with its design locked in and gates that pass, then proposes the first task. In a project that already exists, it adds the same operating rules, gates and runbooks without deleting anything (the overlay). Typed again in a half-finished folder, it resumes from the stage where it stopped.
- `/groundwork:security-audit`: a security review of a codebase, from a focused review to a full audit with a findings report and a coverage ledger.
- Language setting (`language`, default English): the conversation and the documents written from your answers follow it; copied templates, markers, code and commit messages stay English.
- Runs on macOS and Linux; on Windows, use WSL. Needs `git`, `node` and `bash`. `/groundwork:new` no longer needs `jq` to record the plugin version in a project's `CLAUDE.md`.
- Depends on `superpowers@claude-plugins-official` (tested with 7.0.2).

### A project made with 0.1.x

Versions before 1.0.0 are not listed here. To bring a project made with one of them up to 1.0.0:

- Made with 0.1.0 or 0.1.1: in `docs/runbooks/release.md`, row 4 of the section 8 daily check also reads the daily memory maximum of the 7 days before. Below the alert threshold, a maximum that rose 3 days in a row while usage did not is a leak suspect: it goes into the ledger, and the limit is not raised for it.
- If the alert mailbox in the project's `CLAUDE.md` is a no-reply address (such as `…@users.noreply.github.com`), replace it with a mailbox you read.
- `bash scripts/trunk.sh help` now says that `map` prints the page's path and opens it in Weft only when the weft CLI is there, and a few comments in `scripts/lib/trunk/core.sh` and `.github/workflows/ci.yml` were reworded. They run as before, so there is nothing to carry over.
