#!/usr/bin/env bash
# Usage: trunk.sh [status|map|open <name>|merge <name> [--partial]|tidy|help]
# Side branches of a P8 project: open makes one branch and worktree per repo for a plan, merge puts them on main
# after two checks (nothing left out, nothing broken), tidy removes them once the plan is closed, and the map
# shows them. Run it from the root (the umbrella folder, or the repo of a single-repo project) and never wrap
# it in heavy.sh: it wraps each repo's install, verify and check itself. It finds the root from its own
# folder's git, so the copy in a side worktree finds the same root. Only bash, git and basic tools.
# Exit: 0 done, 1 stopped by a check, 2 usage error or refused to run, 3 half merged.
set -u
unset CDPATH
# Git exports GIT_DIR and the like to hooks and to a rebase's exec step; inherited, every git call here would act
# on that repo.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)
export LC_ALL=C # bytes, not characters: plan heads are UTF-8, and awk compares strings by locale
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
for part in core tidy scan map open integrate merge; do
  if [ ! -f "$SCRIPT_DIR/lib/trunk/$part.sh" ]; then
    echo "trunk.sh: no $SCRIPT_DIR/lib/trunk/$part.sh — copy lib/trunk/ along with trunk.sh, next to it" >&2
    exit 2
  fi
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/lib/trunk/$part.sh"
done
trunk_init

usage() {
  cat <<'EOF'
Usage: bash scripts/trunk.sh [command]  (run it from the root; never wrap it in heavy.sh)
  (none)                    the short map
  status                    each side branch's repos and commits
  map                       writes the map HTML, prints its path, and opens it in Weft when the weft CLI is there
  open <name>               opens the plan's side branch: a branch and a worktree of the same name in each repo
  merge <name> [--partial]  merges into main after two checks (nothing left out, nothing broken)
  tidy                      removes the clean side branches whose plan is closed and that are all in
  help                      this text
Exit codes: 0 done · 1 stopped by a check · 2 usage error or refused to run · 3 half merged
EOF
}

case "${1:-}" in
  "")
    [ "$#" -eq 0 ] || { usage >&2; exit 2; }
    cmd_short
    ;;
  status | map)
    [ "$#" -eq 1 ] || { usage >&2; exit 2; }
    "cmd_$1"
    ;;
  help) usage ;;
  tidy)
    [ "$#" -eq 1 ] || { usage >&2; exit 2; }
    cmd_tidy
    ;;
  open)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    cmd_open "$2"
    ;;
  merge)
    if [ "$#" -eq 2 ]; then
      cmd_merge "$2"
    elif [ "$#" -eq 3 ] && [ "$3" = --partial ]; then
      cmd_merge "$2" --partial
    else
      usage >&2
      exit 2
    fi
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
