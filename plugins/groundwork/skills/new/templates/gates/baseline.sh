#!/usr/bin/env bash
# Usage: baseline.sh <gate> [--key <ERE>] [--write] -- <command> [args...]
# The baseline gate: wraps any gate command so the violations a project already had stay listed in
# .baseline/<gate>.txt (sorted keys, one per line) and that list may only shrink. The command runs from the git
# top level with its output shown as is. A failed run yields keys: with --key, each match of the ERE as it is;
# without it, each path-like token that names a file git knows (./ and x/../ folded, so src/a.ts:3:5 and
# src/a.ts(3,5) are src/a.ts) - a file, never a line number. A passing run has no keys, whatever it prints.
# A token ends at a blank or one of :<>"'`,;=| so a path holding one of those is never a key. Brackets and
# parentheses stay in it (app/[id]/page.tsx, app/(group)/x.tsx): the key is the first form git knows of the token
# as it is, without a trailing (N), . ) or ], and without one leading ( or [ and its closer. Each run of
# [A-Za-z0-9_@./+-] is a token too, so a path made only of those bytes is its file even with other bytes glued to
# it (→src/a.ts, src/a.ts’s); a path holding other bytes (app/[id]/…, docs/résumé.md) is not. Such a run can
# also be a fragment that names another file (b.ts in src/a=b.ts): that file becomes a key.
# Exit 1 on a key the list lacks (new violation), a line the base's list lacks (baseline grew), a line no longer
# reported (fixed but still listed), a listed file changed since the base (touched but still violating, file
# keys only), or a failed run with no key in its output. BASELINE_BASE (default HEAD) is the base ref; CI
# passes the pull request's base or the commit the push replaced, and needs the history (fetch-depth 0).
# --write rewrites the list from this run, but only to shrink it, or to create it when the base has none.
# No commit-message marker or switch turns a check off. BASELINE_BASE (CI sets it from the event) picks the base,
# and a base with no list lets a list be created, even one deleted earlier, as a new .baseline/ file in the diff.
# Exit 0 pass, 1 gate failed, 2 usage or setup error. Only bash, git, grep, sed, awk, sort, comm and basic
# tools, so it runs in projects without Node.
set -u
CALLER_LC_ALL=${LC_ALL-}
CALLER_HAS_LC_ALL=${LC_ALL+1}
export LC_ALL=C # bytes: sort and comm agree on order, and grep never takes the output for binary

die() { echo "$2" >&2; exit "$1"; }

usage() {
  echo "baseline: $1" >&2
  echo "usage: baseline.sh <gate> [--key <ERE>] [--write] -- <command> [args...]" >&2
  exit 2
}

# Sets GATE, KEY, WRITE and CMD; anything off is a usage error, found before the command runs.
parse_args() {
  [ "$#" -gt 0 ] || usage "no gate"
  GATE=$1
  shift
  [[ $GATE =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage "bad gate name: $GATE"
  parse_options "$@"
  [ -z "$KEY" ] || check_key
}

parse_options() {
  KEY=
  WRITE=0
  while [ "$#" -gt 0 ]; do
    case $1 in
      --) shift; [ "$#" -gt 0 ] || usage "no command after --"; CMD=("$@"); return 0 ;;
      --write) WRITE=1 ;;
      --key) KEY=${2-}; { [ -n "$KEY" ] && [ "$KEY" != -- ]; } || usage "--key needs a pattern"; shift ;;
      *) usage "unexpected argument: $1" ;;
    esac
    shift
  done
  usage "no -- before the command"
}

check_key() { # grep exits 2 on a pattern it cannot compile
  local rc=0
  grep -qE -e "$KEY" < /dev/null || rc=$?
  [ "$rc" -le 1 ] || usage "bad --key pattern: $KEY"
}

# Moves to the git top level and resolves BASELINE_BASE to BASE_SHA.
enter_repo() {
  local top
  top=$(git rev-parse --show-toplevel) || die 2 "baseline: not inside a git work tree"
  cd "$top" || die 2 "baseline: cannot enter $top"
  BASE=${BASELINE_BASE-HEAD} # set but empty is no base, not HEAD: CI must not compare a commit with itself
  BASE_SHA=$(git rev-parse --verify --quiet "$BASE^{commit}") \
    || die 2 "baseline: base $BASE not found (CI: checkout with fetch-depth 0)"
  LIST=".baseline/$GATE.txt"
}

# Runs the command under the caller's locale, shows its output and keeps a copy; RC is its exit code.
# A command that is not there is a setup error: bash's own error line names this script, a file git knows.
run_gate() {
  command -v "${CMD[0]}" > /dev/null || die 2 "baseline: command not found: ${CMD[0]}"
  (
    if [ -n "$CALLER_HAS_LC_ALL" ]; then export LC_ALL="$CALLER_LC_ALL"; else unset LC_ALL; fi
    exec "${CMD[@]}"
  ) 2>&1 | tee "$WORK/out"
  RC=${PIPESTATUS[0]}
}

# Reads the files git knows (first file), then path tokens (stdin); prints each token's key, if it has one: the first
# of its forms - as it is, trail() and unwrap() - that names a known file once ./ and x/../ are folded. An absolute
# path, or one that climbs out of the top, is no repo file.
token_keys() {
  awk 'function fold(p,   n, seg, kept, top, i, out) {
      if (substr(p, 1, 1) == "/") return ""
      n = split(p, seg, "/"); top = 0
      for (i = 1; i <= n; i++) {
        if (seg[i] == "." || seg[i] == "") continue
        if (seg[i] == ".." && top > 0 && kept[top] != "..") top--
        else kept[++top] = seg[i]
      }
      if (top == 0) return ""
      out = kept[1]
      for (i = 2; i <= top; i++) out = out "/" kept[i]
      return out
    }
    function trail(s) { # a path ending a sentence, a bracket, or a location like (3)
      sub(/\([0-9]+\)\.*$/, "", s); sub(/[].)]+$/, "", s); return s # ] first: POSIX, no \ in a bracket
    }
    function unwrap(s,   o, c) { # (path) or [path], maybe with a dot after it
      o = substr(s, 1, 1)
      if (o != "(" && o != "[") return ""
      c = (o == "(") ? ")" : "]"
      s = substr(s, 2); sub(/\.+$/, "", s)
      if (substr(s, length(s)) == c) s = substr(s, 1, length(s) - 1)
      return s
    }
    function known_form(s,   p) { p = fold(s); return (p != "" && p in known) ? p : "" }
    FILENAME == ARGV[1] { known[$0] = 1; next } # NR == FNR would misread an empty list
    {
      k = known_form($0)
      if (k == "") k = known_form(trail($0))
      if (k == "") k = known_form(unwrap($0))
      if (k != "") print k
    }' "$1" -
}

# V: the keys in the output of a failed run, sorted. Untracked files count: a new file is checked too.
extract_keys() {
  : > "$WORK/v"
  [ "$RC" -ne 0 ] || return 0
  sed -E $'s/\033\\[[0-9;?]*[A-Za-z]//g; s/\r//g' "$WORK/out" > "$WORK/text" # colors and CR glue to a key
  if [ -n "$KEY" ]; then
    grep -aoE -e "$KEY" "$WORK/text" | sort -u > "$WORK/v"
    return 0
  fi
  git -c core.quotePath=false ls-files --cached --others --exclude-standard > "$WORK/files" \
    || die 2 "baseline: git ls-files failed"
  sed -E 's/\(([0-9]+),([0-9]+)\)/:\1:\2/g' "$WORK/text" > "$WORK/text.loc" # (3,5) after a path is :3:5
  { grep -aoE "[^[:space:]:<>\"'\`,;=|]+" "$WORK/text.loc"; grep -aoE '[A-Za-z0-9_@./+-]+' "$WORK/text.loc"; } \
    | token_keys "$WORK/files" | sort -u > "$WORK/v" # wide tokens keep [] and (), narrow ones drop glued bytes
}

keys_of() { tr -d '\r' | sed '/^$/d' | sort -u; }

# T: files changed since the base (staged, unstaged or committed) plus untracked ones. core.quotePath=false keeps
# a path with bytes over 0x7f as it is, as the output prints it, not quoted and escaped.
changed_files() {
  git -c core.quotePath=false diff --name-only "$BASE_SHA" -- > "$WORK/t.raw" \
    || die 2 "baseline: git diff against $BASE failed"
  git -c core.quotePath=false ls-files --others --exclude-standard >> "$WORK/t.raw" \
    || die 2 "baseline: git ls-files failed"
  sort -u "$WORK/t.raw" > "$WORK/t"
}

# B: the list in the work tree (empty when deleted). B0: the list at the base, when it has one (HAS_B0=1).
load_sets() {
  : > "$WORK/b"
  : > "$WORK/b0"
  : > "$WORK/t"
  if [ -f "$LIST" ]; then
    keys_of < "$LIST" > "$WORK/b" || die 2 "baseline: cannot read $LIST"
  elif [ -e "$LIST" ]; then
    die 2 "baseline: $LIST is not a file"
  fi
  local entry
  entry=$(git ls-tree "$BASE_SHA" -- "$LIST") || die 2 "baseline: cannot read the tree of $BASE"
  HAS_B0=0
  if [ -n "$entry" ]; then
    HAS_B0=1
    git cat-file blob "$BASE_SHA:$LIST" > "$WORK/b0.raw" || die 2 "baseline: $LIST at $BASE is not a file"
    keys_of < "$WORK/b0.raw" > "$WORK/b0"
  fi
  [ -n "$KEY" ] || changed_files
}

report() { # report <problem> < keys: one line per key, counted in PROBLEMS
  local k
  while IFS= read -r k; do
    echo "baseline $GATE: $1: $k"
    PROBLEMS=$((PROBLEMS + 1))
  done
}

# Collects every problem; fails if there is one.
check_sets() {
  PROBLEMS=0
  report "new violation" < <(comm -23 "$WORK/v" "$WORK/b")
  [ "$HAS_B0" -eq 0 ] || report "baseline grew" < <(comm -23 "$WORK/b" "$WORK/b0")
  report "fixed but still listed" < <(comm -23 "$WORK/b" "$WORK/v")
  [ -n "$KEY" ] || report "touched but still violating" < <(comm -12 "$WORK/v" "$WORK/b" | comm -12 - "$WORK/t")
  [ "$PROBLEMS" -eq 0 ]
}

# --write: a new list where the base has none, otherwise only a list within the base's.
write_baseline() {
  PROBLEMS=0
  [ "$HAS_B0" -eq 0 ] || report "would grow" < <(comm -23 "$WORK/v" "$WORK/b0")
  [ "$PROBLEMS" -eq 0 ] || exit 1
  { mkdir -p .baseline && cp "$WORK/v" "$LIST"; } || die 2 "baseline: cannot write $LIST"
  echo "baseline $GATE: wrote $(grep -c '' "$LIST") key(s) to $LIST"
}

parse_args "$@"
enter_repo
WORK=$(mktemp -d) || die 2 "baseline: cannot make a temp dir"
trap 'rm -rf "$WORK"' EXIT
run_gate
extract_keys
if [ "$RC" -ne 0 ] && [ ! -s "$WORK/v" ]; then
  echo "baseline $GATE: the command failed but no key was found in its output"
  exit 1
fi
load_sets
if [ "$WRITE" -eq 1 ]; then
  write_baseline
  exit 0
fi
check_sets || exit 1
[ "$RC" -eq 0 ] || echo "baseline $GATE: passed; every key the command failed on is listed in $LIST"
exit 0
