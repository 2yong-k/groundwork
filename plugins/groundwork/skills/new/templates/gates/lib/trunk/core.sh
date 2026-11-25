# Shared checks of trunk.sh, sourced by it: the root, mode and repos, the refusals, the lock, plan heads, the
# milestone table, side branch states, the side worktree conditions, stash and reflog orphans, temp cleanup.
# Arguments that resolve commits take refs/heads/<name>; arguments that take a branch name take the short name.
# A same-named tag would otherwise win the lookup, and refs/heads/ in a name argument makes a new branch of it.

# Sets ROOT (pwd -P), MODE (single|umbrella), UMB (the umbrella name, empty when single), REPOS and KEYS (the
# code repos and their keys: '.' for a single repo, the unit names of an umbrella in key order; never the
# umbrella's docs git, whose key is '.' too), STATE_DIR (lock, merge records, logs) and TMP_ROOT (temp worktrees).
trunk_init() {
  local common d
  if ! common=$(git -C "$SCRIPT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    echo "trunk.sh: $SCRIPT_DIR is not inside a git repo" >&2
    exit 2
  fi
  # The parent of the common git dir, so the copy in a side worktree finds the main checkout too.
  ROOT=$(cd "$common/.." && pwd -P) || exit 2
  # The umbrella name is that of the root .gitignore's '<name>-*/' line, which the umbrella scaffold writes: the
  # folder name can differ from the project's. Without that line it is a single repo, even with a git folder named
  # like the root beside its files (a reference clone).
  UMB=$(grep -m1 -E '^[A-Za-z0-9._-]+-\*/$' "$ROOT/.gitignore" 2>/dev/null | sed 's|-\*/$||')
  MODE=single
  REPOS=()
  KEYS=()
  if [ -n "$UMB" ]; then
    for d in "$ROOT/$UMB"-*; do
      [ -d "$d" ] && [ -e "$d/.git" ] || continue
      KEYS+=("${d##*/"$UMB"-}")
      REPOS+=("$d")
    done
  fi
  if [ "${#KEYS[@]}" -gt 0 ]; then
    MODE=umbrella
  else
    UMB=""
    KEYS=(.)
    REPOS=("$ROOT")
  fi
  STATE_DIR="$ROOT/.superpowers/trunk"
  TMP_ROOT="$ROOT/.worktrees/.trunk-tmp"
}

repo_dir() { if [ "$1" = . ]; then printf '%s\n' "$ROOT"; else printf '%s\n' "$ROOT/$UMB-$1"; fi; } # <key>

spot() { # <key> <name>: where that repo's side worktree lives
  if [ "$MODE" = single ]; then printf '%s\n' "$ROOT/.worktrees/$2"; else printf '%s\n' "$ROOT/.worktrees/$2/$UMB-$1"; fi
}

real_path() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"; } # a dir's pwd -P, any other path unchanged

has_branch() { git -C "$1" show-ref --verify -q "refs/heads/$2"; } # <repo> <name>

in_words() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; } # <word> <space-separated words>

# sh_quote <text>: the text as one shell word, single-quoted only when it holds more than [A-Za-z0-9/._-].
sh_quote() {
  local q="'"
  case "$1" in
    *[!A-Za-z0-9/._-]*) printf "'%s'" "${1//$q/$q\\$q$q}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# A session left in a side folder keeps writing to its old path after tidy removes it, and an open run there
# would nest a side inside a side.
refuse_place() {
  case "$(pwd -P)/" in
    "$ROOT"/.worktrees/*)
      echo "Refused: run it from the root — the current folder $(pwd -P) is under a side branch folder. cd $ROOT, then run again"
      exit 2
      ;;
  esac
}

# The lock order is always trunk.sh, then heavy.sh: wrapped the other way, two merges wait on each other.
refuse_heavy() {
  [ -n "${HEAVY_SH_HELD+set}" ] || return 0
  echo "Refused: trunk.sh is never wrapped in heavy.sh — trunk.sh wraps each repo's install · verify · check in heavy.sh"
  exit 2
}

# on_exit <command> [args...]: runs at EXIT, INT and TERM, the last added first. Callers never set a trap
# themselves: a trap holds one command per signal, so a later one would drop this list.
TRUNK_ON_EXIT=()
on_exit() {
  TRUNK_ON_EXIT+=("$(printf '%q ' "$@")")
  trap trunk_run_exit EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}
trunk_run_exit() {
  local i=${#TRUNK_ON_EXIT[@]}
  while [ "$i" -gt 0 ]; do
    i=$((i - 1))
    eval "${TRUNK_ON_EXIT[$i]}"
  done
  TRUNK_ON_EXIT=()
}

# True when the path exists and was last modified more than $2 seconds ago (GNU or BSD stat).
older_than() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null) || return 1
  [ -n "$m" ] && [ $(($(date +%s) - m)) -gt "$2" ]
}

# kill -0 fails with EPERM for another user's live process; ps -p sees every user's processes.
pid_alive() { kill -0 "$1" 2>/dev/null || ps -p "$1" >/dev/null 2>&1; }

# A lock is stale when its pid is dead, or when it has had no pid for over 10 s (a crash between mkdir and
# the pid write; an empty pid file counts as no pid).
lock_stale() { # <lock dir>
  local owner
  owner=$(cat "$1/pid" 2>/dev/null)
  if [ -z "$owner" ]; then older_than "$1" 10; else ! pid_alive "$owner"; fi
}

# Takes the dir by creating its pid file with noclobber, which opens it O_EXCL, so one process wins. mkdir alone
# is no mutex: uutils mkdir 0.10 reports success to both of two racing callers. The read-back fails a claimer that
# stalled between creating and writing the file until it was cleared.
lock_claim() { # <dir>
  local p
  mkdir "$1" 2>/dev/null && (set -C; echo "$$" >"$1/pid") 2>/dev/null && read -r p 2>/dev/null <"$1/pid" && [ "$p" = "$$" ]
}

# Removes a dir judged stale, but not a claim made since: rmdir leaves a claimed dir alone, and the pid file goes
# only while it names a dead pid, or is empty and over 10 s old (its holder died between creating and writing it).
# Either kind keeps every claimer out until it is gone, so it goes last. A pid-less lock's what and since go only
# while no pid has appeared: a claimer's pid comes before its own.
lock_clear() { # <dir>
  local p
  p=$(cat "$1/pid" 2>/dev/null)
  if { [ -n "$p" ] && ! pid_alive "$p"; } || { [ -z "$p" ] && [ -f "$1/pid" ] && older_than "$1/pid" 10; }; then
    rm -f "$1/what" "$1/since" "$1/pid"
  elif [ ! -e "$1/pid" ]; then
    rm -f "$1/what" "$1/since"
  fi
  rmdir "$1" 2>/dev/null
}

# One breaker at a time, so a late one cannot remove a lock someone else just took. A breaker that crashed leaves
# its dir, cleared by the rules of a lock: a live breaker's dir is kept however old, as a breaker that stalled still
# acts once it resumes.
lock_break() { # <lock dir>
  if ! lock_claim "$1.break"; then
    lock_stale "$1.break" && lock_clear "$1.break"
    return 0
  fi
  lock_stale "$1" && lock_clear "$1"
  lock_unclaim "$1.break"
}

lock_unclaim() { # <dir>: removes it only while its pid is this process's
  if [ "$(cat "$1/pid" 2>/dev/null)" = "$$" ]; then
    rm -f "$1/pid"
    rmdir "$1" 2>/dev/null
  fi
  return 0
}

# lock_take <what>: the one lock of open, merge and tidy. A live holder refuses the run (exit 2).
lock_take() {
  local lock="$STATE_DIR/lock" tries=0 holder by
  mkdir -p "$STATE_DIR" || exit 2
  # Before the first claim, so a run stopped while it breaks a lock frees the break dir too.
  on_exit lock_release
  until lock_claim "$lock"; do
    # Tried again: a lock gone since the claim failed (just released), and a stale one once broken.
    if [ "$tries" -lt 3 ] && { [ ! -d "$lock" ] || lock_stale "$lock"; }; then
      [ ! -d "$lock" ] || lock_break "$lock"
      tries=$((tries + 1))
      continue
    fi
    # A stale lock waits on its breaker, named so that a pid reused by a process that is no breaker can be found.
    # A pid or what file is empty for the moment between its claim and its write.
    if [ ! -d "$lock" ]; then
      echo "Refused: cannot create the lock $lock (disk full, or its parent dir gone or read-only?)"
    elif [ -d "$lock.break" ] && lock_stale "$lock"; then
      holder=$(cat "$lock.break/pid" 2>/dev/null) || holder=''
      echo "Refused: pid ${holder:-?} is breaking a stale lock ($lock.break) — run again once it ends"
    else
      holder=$(cat "$lock/pid" 2>/dev/null) || holder=''
      by=$(cat "$lock/what" 2>/dev/null) || by=''
      echo "Refused: locked by ${by:-?} (pid ${holder:-?}) — run again once it ends"
    fi
    exit 2
  done
  # The pid is the claim, so what and since come after it: a reader can briefly see the pid without them.
  printf '%s\n' "$1" >"$lock/what"
  date '+%Y-%m-%d %H:%M:%S' >"$lock/since"
}

lock_release() { # removes only the lock and the break dir this process holds
  local lock="$STATE_DIR/lock"
  lock_unclaim "$lock.break"
  [ "$(cat "$lock/pid" 2>/dev/null)" = "$$" ] || return 0
  # pid last: while it is there no one else can claim the lock and write their own what and since.
  rm -f "$lock/what" "$lock/since" "$lock/pid"
  rmdir "$lock" 2>/dev/null
  return 0
}

# Plans: docs/plans/*.md but the handoff and the status board, and every .md under docs/archive/.
plan_files() {
  local f
  for f in "$ROOT"/docs/plans/*.md; do
    [ -f "$f" ] || continue
    case "${f##*/}" in handoff.md | status.md) continue ;; esac
    printf '%s\n' "$f"
  done
  [ ! -d "$ROOT/docs/archive" ] || find "$ROOT/docs/archive" -type f -name '*.md' | sort
}

# <side name>\t<plan> for each plan whose first 15 lines hold a side line '> Side branch: <name> · ...'.
plan_sides() {
  local f files=()
  while IFS= read -r f; do files+=("$f"); done < <(plan_files)
  [ "${#files[@]}" -gt 0 ] || return 0
  awk 'FNR > 15 { nextfile }
    /^>? ?Side branch: / {
      s = $0; sub(/^>? ?Side branch: */, "", s); i = index(s, " · "); if (i) s = substr(s, 1, i - 1)
      sub(/[ \t\r]+$/, "", s); print s "\t" FILENAME; nextfile
    }' "${files[@]}"
}

plan_for() { # <name>: the plan of that side; none -> 1, two or more -> 2 (prints them all)
  local hits
  hits=$(plan_sides | TRUNK_NAME="$1" awk -F'\t' '$1 == ENVIRON["TRUNK_NAME"] { print $2 }')
  [ -n "$hits" ] || return 1
  printf '%s\n' "$hits"
  [ "$(printf '%s\n' "$hits" | wc -l)" -eq 1 ] || return 2
}

# plan_field <plan> state|side|milestone|review|wait|hold|scope|resume. state, scope and resume come from
# their own head lines; the rest are fields of the side line, one line per occurrence. One awk, no pipeline: a
# merge and the map read plan heads dozens of times.
plan_field() {
  local key=""
  case "$2" in
    state | scope | resume) ;;
    side) key="Side branch" ;;
    milestone) key=Milestone ;;
    review) key=Review ;;
    wait) key=Waiting ;;
    hold) key="On hold" ;;
    *)
      echo "plan_field: unknown field $2" >&2
      return 2
      ;;
  esac
  awk -v what="$2" -v k="$key: " '
    function rtrim(s) { sub(/[ \t\r\v\f]+$/, "", s); return s }
    NR > 15 { exit }
    what == "state" { if ($0 ~ /^>? ?Status: *(draft|approved|active|done|dropped|superseded)/) { sub(/^>? ?Status: */, ""); print rtrim($0); exit } next }
    what == "scope" { if ($0 ~ /^>? ?scope: /) { sub(/^>? ?scope: */, ""); print rtrim($0); exit } next }
    what == "resume" { if (index($0, "Resume at:")) { sub(/^.*Resume at: */, ""); print rtrim($0); exit } next }
    /^>? ?Side branch: / {
      sub(/^>? ?/, "")
      n = split($0, f, / · /)
      for (i = 1; i <= n; i++) if (index(f[i], k) == 1) { v = substr(f[i], length(k) + 1); sub(/[ \t\r]+$/, "", v); print v }
      exit
    }' "$1" 2>/dev/null
  return 0
}

plan_closed() { case "$(plan_field "$1" state)" in done* | dropped* | superseded*) return 0 ;; esac; return 1; }

# Open boxes outside code blocks. The awk program is outside_fences of check-docs.sh, copied character for
# character (keep the two equal), and the box pattern is its BOX: when merge and the docs gate count open tasks
# differently, the commit that closes the plan is blocked. A code block that never closes counts as one more: the
# docs gate refuses to close such a plan, since the block can hide open boxes.
open_boxes() {
  local box='[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+\['
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
  } END { if (open) print "unclosed:" start }' "$1" | { grep -cE "^([0-9]+:$box \]|unclosed:)" || true; }
}

# review_hash <plan> <key>: that repo's hash in the side line's Review: field (a bare hash for a single repo,
# <unit>@<hash> in an umbrella). None -> 1, twice -> 2 (prints both).
review_hash() {
  local tok hits=()
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    if [ "$2" = . ]; then
      case "$tok" in *@*) ;; *) hits+=("$tok") ;; esac
    else
      case "$tok" in "$2"@*) hits+=("${tok#*@}") ;; esac
    fi
  done < <(plan_field "$1" review | tr ' \t' '\n\n')
  case "${#hits[@]}" in
    0) return 1 ;;
    1) printf '%s\n' "${hits[0]}" ;;
    *)
      printf '%s\n' "${hits[@]}"
      return 2
      ;;
  esac
}

# The status board's '## Milestones' table, columns '| Milestone | Name · goal | Status | staging QA |',
# as <version>\t<state>\t<date>\t<name · goal>\t<QA> per row; reached (2026-11-12) gives reached and its date. No file,
# no table or a version cell that is not vX.Y.Z -> 1 and no rows.
milestones() {
  local f="$ROOT/docs/plans/status.md"
  [ -f "$f" ] || return 1
  awk -F'|' '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    /^## / { on = ($0 ~ /^## Milestones[ \t\r]*$/); next }
    !on || !/^\|/ { next }
    { v = trim($2) }
    v == "Milestone" { head = 1; next }
    v ~ /^:?-+:?$/ { next }
    v !~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { bad = 1; next }
    {
      st = trim($4); date = ""
      if (match(st, /\(.*\)/)) { date = trim(substr(st, RSTART + 1, RLENGTH - 2)); st = trim(substr(st, 1, RSTART - 1)) }
      row[++n] = v "\t" st "\t" date "\t" trim($3) "\t" trim($5)
    }
    END { if (!head || bad) exit 1; for (i = 1; i <= n; i++) print row[i] }' "$f"
}

# The milestone check: Milestone: tbd passes (it counts as the earliest open one); a version must be in
# the table and no later than the earliest open row; with no open row it passes. Fails print the reason.
milestone_gate() { # <plan>
  local want rows
  want=$(plan_field "$1" milestone | head -n 1)
  [ "$want" != tbd ] || return 0
  if [ ! -f "$ROOT/docs/plans/status.md" ]; then
    echo "not in the milestone table: ${want:-(Milestone: none)} — no status board (docs/plans/status.md). A plan that names a milestone is checked against the status board's '## Milestones' table"
    return 1
  fi
  if ! rows=$(milestones); then
    echo "not in the milestone table: ${want:-(Milestone: none)} — could not read the status board's '## Milestones' table"
    return 1
  fi
  printf '%s\n' "$rows" | awk -F'\t' -v w="$want" '
    function num(v, i,  p) { sub(/^v/, "", v); split(v, p, "."); return p[i] + 0 }
    function later(a, b,  i) { for (i = 1; i <= 3; i++) if (num(a, i) != num(b, i)) return num(a, i) > num(b, i); return 0 }
    $1 == w { known = 1 }
    $2 == "open" && (first == "" || later(first, $1)) { first = $1 }
    END {
      if (!known) { print "not in the milestone table: " (w == "" ? "(Milestone: none)" : w); exit 1 }
      if (first != "" && later(w, first)) { print "waits for the next milestone: " w " — the earliest open milestone is " first; exit 1 }
    }'
}

# <ok|locked|prunable>\t<refs/heads/... or ->\t<path> for each worktree of the repo.
wt_list() {
  git -C "$1" worktree list --porcelain 2>/dev/null | awk '
    function out() { if (p != "") print st "\t" (br == "" ? "-" : br) "\t" p; p = "" }
    /^worktree / { out(); p = substr($0, 10); br = ""; st = "ok"; next }
    /^branch / { br = substr($0, 8); next }
    /^locked/ { st = "locked"; next }
    /^prunable/ { if (st == "ok") st = "prunable"; next }
    END { out() }'
}

# wt_id <repo> <worktree path>: the <id> of .git/worktrees/<id> that records the path, also when the folder is
# gone (a prunable record).
wt_id() {
  local common g p want
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  want=$(real_path "$2")
  for g in "$common"/worktrees/*/gitdir; do
    [ -f "$g" ] || continue
    p=$(cat "$g")
    case "$p" in /*) ;; *) p="${g%/gitdir}/$p" ;; esac
    if [ "$(real_path "${p%/.git}")" = "$want" ]; then
      g=${g%/gitdir}
      printf '%s\n' "${g##*/}"
      return 0
    fi
  done
  return 1
}

# side_state <key> <name>: side (marker and a live worktree at the side spot),
# half-made (marker, no worktree), prunable (marker, only a prunable worktree record), no-marker, bad-marker
# (the start hash is not an ancestor of both the branch and main), elsewhere (worktree outside the spot),
# locked (locked worktree), none (no such branch).
side_state() {
  local repo mark start st br p
  repo=$(repo_dir "$1")
  has_branch "$repo" "$2" || { echo none; return 0; }
  mark=$(git -C "$repo" config --get "branch.$2.trunk")
  [ -n "$mark" ] || { echo no-marker; return 0; }
  if ! start=$(git -C "$repo" rev-parse -q --verify "$mark^{commit}") \
    || ! git -C "$repo" merge-base --is-ancestor "$start" "refs/heads/$2" \
    || ! git -C "$repo" merge-base --is-ancestor "$start" refs/heads/main; then
    echo bad-marker
    return 0
  fi
  while IFS=$'\t' read -r st br p; do
    [ "$br" = "refs/heads/$2" ] || continue
    case "$st" in locked | prunable) echo "$st"; return 0 ;; esac
    if [ "$(real_path "$p")" = "$(real_path "$(spot "$1" "$2")")" ]; then echo side; else echo elsewhere; fi
    return 0
  done < <(wt_list "$repo")
  echo half-made
}

in_progress() { # <worktree>: each operation in progress there, one per line
  local items="MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG rebase-merge rebase-apply sequencer" item args=() paths=() p i=0
  for item in $items; do args+=(--git-path "$item"); done
  # Absolute paths: relative ones from a main checkout would be read against the wrong folder.
  while IFS= read -r p; do paths+=("$p"); done < <(git -C "$1" rev-parse --path-format=absolute "${args[@]}" 2>/dev/null)
  for item in $items; do
    [ -n "${paths[$i]:-}" ] && [ -e "${paths[$i]}" ] && echo "$item"
    i=$((i + 1))
  done
  return 0
}

# wt_faults <worktree> <name>: each side worktree condition it breaks, one per line: head (HEAD
# is not refs/heads/<name>), op:<item> (in progress), dirty (status shows anything; the flags override user
# config that hides untracked files), stash:<line> (a stash of this branch), loose-stash:<hash> (a stash no
# branch owns: '(no branch)' or autostash, which blocks every side of the repo).
wt_faults() {
  local st h msg item
  [ "$(git -C "$1" symbolic-ref -q HEAD)" = "refs/heads/$2" ] || echo head
  while IFS= read -r item; do echo "op:$item"; done < <(in_progress "$1")
  if ! st=$(git -C "$1" status --porcelain --untracked-files=all --ignore-submodules=none 2>/dev/null) || [ -n "$st" ]; then
    echo dirty
  fi
  while read -r h msg; do
    case "$msg" in
      "On $2: "* | "WIP on $2: "*) echo "stash:$msg" ;;
      "On (no branch): "* | "WIP on (no branch): "* | autostash) echo "loose-stash:$h" ;;
    esac
  done < <(git -C "$1" stash list --format='%H %gs' 2>/dev/null)
  return 0
}

# reflog_orphans <repo> <worktree id>: commits of that worktree's HEAD reflog that no branch reflog ever held
# and no ref holds now: work made on a detached HEAD and left. The worktree's removal drops them with its reflog.
# Entries whose message starts with rebase are a rebase's intermediates and do not count.
reflog_orphans() {
  local cands branches seen loose
  cands=$(git -C "$1" reflog show --format='%H %gs' "worktrees/$2/HEAD" 2>/dev/null | awk '$2 !~ /^rebase/ && !s[$1]++ { print $1 }')
  [ -n "$cands" ] || return 0
  cands=$(printf '%s\n' "$cands" | git -C "$1" cat-file --batch-check='%(objectname) %(objecttype)' | awk '$2 == "commit" { print $1 }')
  [ -n "$cands" ] || return 0
  branches=$(git -C "$1" for-each-ref --format='%(refname)' refs/heads/)
  seen=""
  # shellcheck disable=SC2086
  [ -z "$branches" ] || seen=$(git -C "$1" log -g --format=%H $branches 2>/dev/null)
  # shellcheck disable=SC2086
  loose=$(git -C "$1" rev-list $cands --not --all 2>/dev/null)
  {
    printf '%s\n' "$seen" | sed 's/^/s /'
    printf '%s\n' "$loose" | sed 's/^/l /'
    printf '%s\n' "$cands" | sed 's/^/c /'
  } | awk '$1 == "s" { s[$2] = 1; next } $1 == "l" { l[$2] = 1; next } $1 == "c" && $2 != "" && !s[$2] && l[$2] { print $2 }'
}

# rec_raised <name>: the keys of the merge record (lines '<key> <old main> <temp tip>') whose main
# holds that temp tip, the repos already raised.
rec_raised() {
  local f="$STATE_DIR/merge-$1.rec" key old tip
  [ -f "$f" ] || return 0
  while read -r key old tip; do
    [ -n "$tip" ] || continue
    if git -C "$(repo_dir "$key")" merge-base --is-ancestor "$tip" refs/heads/main 2>/dev/null; then printf '%s\n' "$key"; fi
  done <"$f"
  return 0
}

merge_commits() { # <key> <name>: main's first-parent commits titled chore(trunk): merge <name>, newest first
  git -C "$(repo_dir "$1")" log --first-parent --format='%H %s' refs/heads/main 2>/dev/null \
    | TRUNK_NAME="$2" awk '{ h = $1; sub(/^[^ ]+ /, "") } $0 == "chore(trunk): merge " ENVIRON["TRUNK_NAME"] { print h }'
}

ahead() { git -C "$(repo_dir "$1")" rev-list --count "refs/heads/$2" ^refs/heads/main 2>/dev/null; } # <key> <name>

# tmp_remove <path>: removes a temp worktree (detached ones too) by path, only under TMP_ROOT,
# then each repo's records under TMP_ROOT whose folder is gone. Never git worktree prune: it would also drop the
# record of a side folder deleted by hand, and with it the HEAD reflog that open reads for commits left on a
# detached HEAD. Its temp branch trunk-tmp/<name> goes with update-ref -d: a failed integration commit is on no
# main, so the branch delete that refuses unmerged work would refuse it.
tmp_remove() {
  local p="$1" base real k repo st br q
  base=$(real_path "$TMP_ROOT")
  if [ -e "$p" ] || [ -L "$p" ]; then
    if [ -d "$p" ] && [ ! -L "$p" ]; then real=$(real_path "$p"); else real="$(real_path "$(dirname "$p")")/${p##*/}"; fi
    case "$real" in
      "$base"/?*) ;;
      *)
        echo "Temp removal refused: $p is not under $TMP_ROOT"
        return 1
        ;;
    esac
    for k in "${KEYS[@]}"; do git -C "$(repo_dir "$k")" worktree unlock "$p" >/dev/null 2>&1; done
    rm -rf "$p"
  fi
  # A record whose folder is gone goes alone with worktree remove; a locked one has to be unlocked first.
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    while IFS=$'\t' read -r st br q; do
      case "$(real_path "$q")/" in
        "$base"/?*)
          [ ! -e "$q" ] || continue
          [ "$st" != locked ] || git -C "$repo" worktree unlock "$q" >/dev/null 2>&1
          git -C "$repo" worktree remove "$q" >/dev/null 2>&1
          ;;
      esac
    done < <(wt_list "$repo")
  done
  return 0
}
