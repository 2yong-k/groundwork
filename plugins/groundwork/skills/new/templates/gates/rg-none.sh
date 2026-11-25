#!/usr/bin/env bash
# Usage: rg-none.sh <rg arguments>...
# A gate step that passes only when rg finds nothing: no match -> exit 0, a match -> exit 1 (matches
# printed), an rg error (missing dir, bad pattern) or no rg at all -> exit 2. It is one command, so it
# is safe anywhere in an `a && b && c` gate chain; a bare `! rg ...` passes when rg is missing or the
# dir is wrong, and comparing rg's exit code after a `;` hides a failure of the steps before it.
set -u

if [ "$#" -eq 0 ]; then
  echo "usage: rg-none.sh <rg arguments>..." >&2
  exit 2
fi
# rg may be a shell function (not visible to scripts); Claude Code ships rg inside its binary.
if command -v rg >/dev/null 2>&1 && [ -x "$(command -v rg)" ]; then
  run_rg() { rg "$@"; }
elif [ -x "${CLAUDE_CODE_EXECPATH:-}" ]; then
  run_rg() { ARGV0=rg "$CLAUDE_CODE_EXECPATH" "$@"; }
else
  echo "rg-none: ripgrep (rg) is required" >&2
  exit 2
fi

run_rg "$@"
case $? in
  1) exit 0 ;;
  0) echo "rg-none: the matches above are not allowed" >&2; exit 1 ;;
  *) exit 2 ;;
esac
