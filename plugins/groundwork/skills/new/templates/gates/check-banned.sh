#!/usr/bin/env bash
# Usage: check-banned.sh <patterns.txt> <dir>...
# Fails (exit 1) and prints "file:line: <pattern>" for every line matching a banned pattern.
# A line containing "banned-ok:" is skipped. Exit 2 on usage or rg errors.
set -u

if [ "$#" -lt 2 ]; then
  echo "usage: check-banned.sh <patterns.txt> <dir>..." >&2
  exit 2
fi
# rg may be a shell function (not visible to scripts); Claude Code ships rg inside its binary.
if command -v rg >/dev/null 2>&1 && [ -x "$(command -v rg)" ]; then
  run_rg() { rg "$@"; }
elif [ -x "${CLAUDE_CODE_EXECPATH:-}" ]; then
  run_rg() { ARGV0=rg "$CLAUDE_CODE_EXECPATH" "$@"; }
else
  echo "check-banned: ripgrep (rg) is required" >&2
  exit 2
fi

patterns_file="$1"; shift
[ -f "$patterns_file" ] || { echo "check-banned: no such patterns file: $patterns_file" >&2; exit 2; }

found=0
while IFS= read -r pattern || [ -n "$pattern" ]; do
  case "$pattern" in ''|'#'*) continue ;; esac
  out=$(run_rg -n -H --no-heading --pcre2 -e "$pattern" -- "$@" 2>&1); code=$?
  if [ "$code" -ge 2 ]; then
    echo "$out" >&2
    exit 2
  fi
  [ "$code" -eq 0 ] || continue
  while IFS= read -r hit; do
    rest="${hit#*:}"            # drop file
    text="${rest#*:}"           # drop line number
    case "$text" in *banned-ok:*) continue ;; esac
    echo "${hit%%:"$text"}: $pattern"
    found=1
  done <<< "$out"
done < "$patterns_file"

exit "$found"
