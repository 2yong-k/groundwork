#!/usr/bin/env bash
# Usage: check-docs.sh [docs dir, default docs]
# The docs gate: every spec and plan states its state, and that state agrees with its boxes, its
# same-named spec and the handoff. A plan in progress says where to resume, finished work names a
# commit, ledger ids and ADR numbers are used once, the files read every session stay small, and no
# spec or plan escapes to docs/superpowers. Any failure -> exit 1, no docs dir -> exit 2. A hash git
# cannot find only warns (exit 0): a rewrite or a sibling repo is no reason to stop a commit, and neither
# are closed plans piling up in docs/plans (they warn past CLOSED_PLANS_MAX). Only
# bash, grep, awk and basic tools, so it runs in projects without Node.
set -u
export LC_ALL=C # bytes, not characters: in UTF-8 one invalid byte stops awk, and the gate would pass unread lines

DOCS="${1:-docs}"
if [ ! -d "$DOCS" ]; then
  echo "check-docs: $DOCS is not a directory" >&2
  exit 2
fi
shopt -s nullglob
HANDOFF_MAX=10240
STATUS_MAX=10240
CLAUDE_MAX=20480
UMBRELLA_CLAUDE_MAX=8149
LEDGER_MAX=51200
CLOSED_PLANS_MAX=10 # past this, closed plans bury the open ones in docs/plans
LEDGER_ROW='^\| (DEF|UX|REQ|SEC|DEBT)-[0-9]+ '
BOX='[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+\[' # a list item that opens a checkbox, before what is inside
UMBRELLA="$(cd "$DOCS/.." && pwd)"
fails=0
closed_plans=0

fail() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

# The state of a document, like done (2026-11-05, abc1234); nothing if the first 15 lines have none.
state_of() {
  head -n 15 "$1" | grep -m1 -E '^>? ?Status: *(draft|approved|active|done|dropped|superseded)' | sed -E 's/^>? ?Status: *//'
}

is_closed() { case "$1" in done* | dropped* | superseded*) return 0 ;; esac; return 1; }

# Prints <line number>:<line> for each line outside a code block. Only a bare fence of the same kind, at
# least as long as the opening one, closes the block, so a four-backtick block can quote a three-backtick
# line. A backtick in the info string makes it inline code, not a fence (CommonMark).
# A block still open at the end adds a last line, unclosed:<line it opened on>.
outside_fences() {
  awk '{
    line = $0; sub(/^ +/, "", line); kind = ""
    if (match(line, /^```+/)) { if (substr(line, RLENGTH + 1) !~ /`/) kind = "`" }
    else if (match(line, /^~~~+/)) kind = "~"
    if (kind != "") {
      if (!open) { open = RLENGTH; opened = kind; start = NR; next }
      if (kind == opened && RLENGTH >= open && line ~ /^(`+|~+)[ \t]*$/) open = 0
      next
    }
    if (!open) print NR ":" $0
  } END { if (open) print "unclosed:" start }' "$1"
}

boxes() { outside_fences "$1" | grep -cE "^[0-9]+:$BOX$2\]"; } # boxes <file> <what is inside the brackets>

# Eight digits starting 19 or 20 read as a date. A 7-digit hash stays one: 4% of short hashes are all digits.
is_hash() { printf '%s\n' "$1" | grep -E '^([A-Za-z0-9_-]+@)?[0-9a-f]{7,40}$' | grep -qvE '^(19|20)[0-9]{6}$'; }

# Warns when git cannot find a commit. The token is <hash>, or <repo>@<hash> for the sibling folder
# <umbrella>-<repo>. Anything else is no hash. No such folder, no git or a shallow clone: no check.
check_hash() {
  local file="$1" token="$2" target="$DOCS"
  is_hash "$token" || return 0
  case "$token" in
    *@*)
      target="$UMBRELLA/${UMBRELLA##*/}-${token%%@*}"
      [ -d "$target" ] || return 0
      ;;
  esac
  [ "$(git -C "$target" rev-parse --is-shallow-repository 2>/dev/null)" = false ] || return 0
  git -C "$target" cat-file -e "${token##*@}^{commit}" 2>/dev/null || echo "WARN $file: $token not found"
}

# Finished work names a commit, like done (date, hash) in a document or a ledger row. Usage: <file> <word> <text> [<row id>]
check_named_commit() {
  local inner="${3#*"$2"}" token found=0
  inner="${inner# }"
  inner="${inner#(}"
  for token in $(printf '%s\n' "${inner%%)*}" | sed 's/\.\./ /g' | tr -d '`' | tr ',' ' '); do
    if is_hash "$token"; then
      found=1
      check_hash "$1" "$token"
    fi
  done
  [ "$found" -eq 1 ] || fail "$1" "${4:-$2} names no commit hash"
}

check_title_hashes() { # the last code of a heading that ends in code
  local token
  outside_fences "$1" | grep -E '^[0-9]+:#.*`[^`]+`[[:space:]]*$' | sed -E 's/.*`([^`]+)`[[:space:]]*$/\1/' \
    | while IFS= read -r token; do check_hash "$1" "$token"; done
}

check_done_plan() {
  local open_lines unclosed
  open_lines="$(outside_fences "$1" | grep -E "^[0-9]+:$BOX \]" | cut -d: -f1 | tr '\n' ' ')"
  [ -z "$open_lines" ] || fail "$1" "finished plan has open boxes on lines: $open_lines"
  unclosed="$(outside_fences "$1" | sed -n 's/^unclosed://p')"
  [ -z "$unclosed" ] || fail "$1" "finished plan has a code block from line $unclosed that never closes; it can hide open boxes"
}

check_plan() { # check_plan <file> <state>
  case "$2" in
    done*) check_done_plan "$1" ;;
    active*)
      head -n 15 "$1" | grep -q 'Resume at:' || fail "$1" "plan in progress has no Resume at: line in the first 15 lines"
      if [ "$(boxes "$1" ' ')" -eq 0 ] && [ "$(boxes "$1" '[xX]')" -gt 0 ]; then
        echo "WARN $1: no open box left; close the plan (done) in the next commit"
      fi
      ;;
    draft* | approved*)
      [ "$(boxes "$1" '[xX]')" -eq 0 ] || fail "$1" "has checked boxes, so the work started; set Status: active and Resume at:"
      ;;
  esac
  check_title_hashes "$1"
}

# Prints a plan's spec: the same name, or the same topic when written on different days and the topic names one of each.
spec_of() {
  local stem="${1##*/}" topic specs plans
  stem="${stem%.md}"
  if [ -f "$DOCS/specs/$stem-design.md" ]; then echo "$DOCS/specs/$stem-design.md"; return; fi
  topic="${stem#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}"
  specs=("$DOCS"/specs/????-??-??-"$topic"-design.md)
  plans=("$DOCS"/plans/????-??-??-"$topic".md)
  if [ "${#specs[@]}" -eq 1 ] && [ "${#plans[@]}" -eq 1 ]; then echo "${specs[0]}"; fi
}

# A plan and its spec close together, in one commit. A dropped or replaced plan may leave its spec open;
# a closed spec of any kind leaves nothing for its plan to build.
check_pair() { # check_pair <plan file> <plan state>
  local spec spec_state
  spec="$(spec_of "$1")"
  [ -n "$spec" ] || return 0
  spec_state="$(state_of "$spec")"
  case "$2" in done*) is_closed "$spec_state" || fail "$spec" "its plan is done, so close this spec in the same commit" ;; esac
  if is_closed "$spec_state" && ! is_closed "$2"; then fail "$1" "its spec is ${spec_state%%[ (]*}, so close this plan in the same commit"; fi
}

check_max() { # check_max <file> <bytes> <what to do>
  if [ -f "$1" ] && [ "$(wc -c <"$1")" -gt "$2" ]; then fail "$1" "over $2 bytes; $3"; fi
}

# Section 1 of the handoff comes first when /groundwork:new resumes, so its Start at must not send a session to closed
# work. Details may point anywhere: it names an owner doc. A line with no Start at counts whole.
check_handoff() {
  local file="$DOCS/plans/handoff.md" path state
  [ -f "$file" ] || return 0
  check_max "$file" "$HANDOFF_MAX" "move what stays true to the status board"
  for path in $(awk '/^## /{ on = /^## 1\./ } on' "$file" | sed -E 's/^.*Start at://; s/Details:.*$//' \
    | grep -oE '(docs/)?plans/[^[:space:]`),]+\.md' | sort -u); do
    [ -f "$DOCS/plans/${path##*/}" ] || continue
    state="$(state_of "$DOCS/plans/${path##*/}")"
    if is_closed "$state"; then fail "$file" "section 1 points at $path, which is ${state%%[ (]*}"; fi
  done
}

# Every session loads CLAUDE.md, and an umbrella's is loaded in each of its repos too.
check_claude_md() {
  local file="$UMBRELLA/CLAUDE.md"
  [ -f "$file" ] || return 0
  if grep -q '^## Repo map' "$file"; then
    check_max "$file" "$UMBRELLA_CLAUDE_MAX" "shorten the table values and shared rules; repo rules belong in that repo's CLAUDE.md"
  else
    check_max "$file" "$CLAUDE_MAX" "move procedures to docs/runbooks and drop Mistakes log lines whose trap is gone"
  fi
}

check_ledger() {
  local file="$DOCS/ledger.md" twice id status
  [ -f "$file" ] || return 0
  twice="$(cat "$file" "$DOCS"/archive/ledger-closed-*.md | grep -oE "$LEDGER_ROW" | sort | uniq -d | tr -d '| ' | tr '\n' ' ')"
  [ -z "$twice" ] || fail "$file" "ids used twice across the ledger and its archive: $twice"
  while IFS='|' read -r id status; do
    check_named_commit "$file" done "$status" "${id// /}"
  done < <(grep -E "$LEDGER_ROW" "$file" | awk -F'|' '$(NF - 1) ~ /^ *done/ { print $2 "|" $(NF - 1) }')
  [ "$(wc -c <"$file")" -gt "$LEDGER_MAX" ] || return 0
  if grep -E "$LEDGER_ROW" "$file" | awk -F'|' '$(NF - 1) ~ /^ *(done|dropped)/ { found = 1 } END { exit !found }'; then
    fail "$file" "over $LEDGER_MAX bytes; move finished rows to docs/archive/"
  else
    echo "WARN $file: over $LEDGER_MAX bytes with every row open"
  fi
}

# ADR numbers are ids too: two sessions that each take the next number leave two decisions on one id.
check_adr_numbers() {
  local f twice
  twice="$(for f in "$DOCS"/adr/[0-9][0-9][0-9][0-9]-*.md; do f="${f##*/}"; echo "${f%%-*}"; done | sort | uniq -d | tr '\n' ' ')"
  [ -z "$twice" ] || fail "$DOCS/adr" "ADR numbers used twice: $twice"
}

for file in "$DOCS"/specs/*.md "$DOCS"/plans/*.md; do
  case "${file##*/}" in handoff.md | status.md) continue ;; esac
  state="$(state_of "$file")"
  if [ -z "$state" ]; then
    fail "$file" "no Status: line in the first 15 lines"
    continue
  fi
  case "$state" in done*) check_named_commit "$file" done "$state" ;; esac
  case "$file" in
    "$DOCS"/plans/*)
      check_plan "$file" "$state"
      check_pair "$file" "$state"
      if is_closed "$state"; then closed_plans=$((closed_plans + 1)); fi
      ;;
  esac
done
[ "$closed_plans" -le "$CLOSED_PLANS_MAX" ] \
  || echo "WARN $DOCS/plans: $closed_plans closed plans; at the next release git mv closed specs and plans to $DOCS/archive/"

check_handoff
check_max "$DOCS/plans/status.md" "$STATUS_MAX" "move procedures to docs/runbooks"
check_claude_md
check_ledger
check_adr_numbers
[ ! -d "$DOCS/superpowers" ] || fail "$DOCS/superpowers" "this gate cannot see it; move specs to $DOCS/specs and plans to $DOCS/plans"

if [ "$fails" -gt 0 ]; then exit 1; fi
