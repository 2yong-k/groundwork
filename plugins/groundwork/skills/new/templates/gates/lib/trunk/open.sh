# trunk.sh open <name> and its entry screen, sourced by trunk.sh. Every repo is judged
# before anything is made: judging and making repo by repo would leave a half-open side when a later repo stops.
# A rerun picks up what a dead run left: it adds a missing worktree, the missing links and env copies, and makes
# nothing twice.

ENTRY_LEDGER_CAP=5 # ledger ids the entry lists; the rest is 'Ledger, <N> more'

open_stop() { echo "Stop: $1: $2"; OPEN_STOPPED=1; } # <key> <reason>

# open_name_ok <name>: a name git takes as a branch name as it is. check-ref-format --branch
# expands @{-1} and the like, so its answer must be the name itself.
open_name_ok() {
  [ -n "$1" ] && [ "$(git -C "$ROOT" check-ref-format --branch "$1" 2>/dev/null)" = "$1" ] && return 0
  echo "Refused: bad name '$1' — only a plan topic that passes git check-ref-format --branch unchanged can be a side branch name"
  exit 2
}

# open_plan <name> (step 2): sets OPEN_PLAN to the one open plan whose side line names it and whose file name,
# less the date and .md, is the name.
open_plan() {
  local name="$1" plans topic rc
  plans=$(plan_for "$name")
  rc=$?
  case "$rc" in
    0) ;;
    1)
      open_stop . "no plan — no plan in docs/plans/ or docs/archive/ has 'Side branch: $name' in its head"
      return 1
      ;;
    *)
      open_stop . "two or more plans — $(printf '%s\n' "$plans" | paste -sd' ' -)"
      return 1
      ;;
  esac
  if plan_closed "$plans"; then
    open_stop . "plan closed — $plans ($(plan_field "$plans" state))"
    return 1
  fi
  topic=${plans##*/}
  topic=${topic%.md}
  case "$topic" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) topic=${topic#???????????} ;; esac
  if [ "$topic" != "$name" ]; then
    open_stop . "name differs from the plan topic — the topic of $plans is $topic"
    return 1
  fi
  OPEN_PLAN=$plans
}

# open_scope <plan> (step 4): sets OPEN_SCOPE to the keys the plan touches, in key order: '.' for a single repo,
# the units of the plan's '> scope: fe+be' in an umbrella, every repo for '> scope: all'.
open_scope() {
  local raw u k ok
  local -a units=()
  OPEN_SCOPE=""
  if [ "$MODE" = single ]; then
    OPEN_SCOPE=.
    return 0
  fi
  raw=$(plan_field "$1" scope)
  IFS='+ ' read -r -a units <<<"$raw"
  if [ "${#units[@]}" -eq 0 ]; then
    open_stop . "no scope in the plan head — an umbrella names the repos to touch with '> scope: <unit>+<unit>'"
    return 1
  fi
  if in_words all "${units[*]}"; then units=("${KEYS[@]}"); fi
  for u in "${units[@]}"; do
    ok=0
    for k in "${KEYS[@]}"; do [ "$k" != "$u" ] || ok=1; done
    [ "$ok" -eq 1 ] || open_stop . "scope unit $u is not a repo of this umbrella (repos: ${KEYS[*]})"
  done
  [ "${OPEN_STOPPED:-0}" -eq 0 ] || return 1
  for k in "${KEYS[@]}"; do
    for u in "${units[@]}"; do
      if [ "$u" = "$k" ]; then
        OPEN_SCOPE="${OPEN_SCOPE:+$OPEN_SCOPE }$k"
        break
      fi
    done
  done
}

in_scope() { in_words "$1" "$OPEN_SCOPE"; } # <key>

# branch_record <repo> <name>: '<ok|locked|prunable>\t<path>' of the first worktree record on that branch.
branch_record() {
  wt_list "$1" | awk -F'\t' -v b="refs/heads/$2" '$2 == b { print $1 "\t" $3; exit }'
}

lock_reason() { # <repo> <name>: why the worktree on that branch is locked ('no reason' for none given)
  git -C "$1" worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$2" '
    /^worktree / { br = ""; next }
    /^branch / { br = substr($0, 8); next }
    /^locked/ && br == b { r = substr($0, 8); print (r == "" ? "no reason" : r); exit }'
}

# fix_hint <repo> <name>: the way out for a same-named branch with no marker, no worktree record and no commits
# of its own. git branch -d refuses one with a worktree record, and whether a worktree or commits go is the user's call.
fix_hint() {
  [ -z "$(git -C "$1" config --get "branch.$2.trunk")" ] || return 0
  [ -z "$(branch_record "$1" "$2")" ] || return 0
  [ "$(git -C "$1" rev-list --count "refs/heads/$2" ^refs/heads/main 2>/dev/null)" = 0 ] || return 0
  printf ' · fix: git -C %s branch -d %s, then run open again' "$(sh_quote "$1")" "$(sh_quote "$2")"
}

# not_side_why <key> <name> <side_state>: why a same-named branch is no side.
not_side_why() {
  local repo rec why lk
  repo=$(repo_dir "$1")
  rec=$(branch_record "$repo" "$2")
  case "$3" in
    no-marker) why="no side branch marker" ;;
    bad-marker) why="side branch marker $(git -C "$repo" config --get "branch.$2.trunk") is not an ancestor of both the branch and main" ;;
    elsewhere) why="worktree outside the side branch spot: ${rec#*$'\t'}" ;;
    locked) why="worktree locked" ;;
    prunable) why="only the worktree record is left (prunable) — the side branch folder was deleted. Rerun open to resume" ;;
    half-made) why="no side worktree — rerun open to resume" ;;
    *) why="$3" ;;
  esac
  case "$rec" in
    locked*)
      lk=$(lock_reason "$repo" "$2")
      why="$why · lock reason: $lk"
      [ "$lk" != initializing ] || why="$why (left by a git worktree add that died midway)"
      ;;
  esac
  printf '%s%s' "$why" "$(fix_hint "$repo" "$2")"
}

# spot_taken <path>: something git worktree add would refuse is there (anything but an empty folder).
spot_taken() { [ -L "$1" ] || { [ -e "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]; }; }

open_add() { OPEN_KEYS+=("$1"); OPEN_DO+=("$2"); OPEN_REC+=("${3:--}"); } # <key> <resume|worktree|record|create> [<record>]

# open_prunable <key> <record path>: what removing that prunable record would lose: commits its
# HEAD reflog alone holds and its refs/worktree/ refs (another worktree's own refs show only through its admin
# folder). Each is a stop; whether they go is the user's call.
open_prunable() {
  local k="$1" repo id common h ref
  repo=$(repo_dir "$k")
  if ! id=$(wt_id "$repo" "$2"); then
    open_stop "$k" "could not find the worktree record: $2"
    return 0
  fi
  while IFS= read -r h; do
    [ -z "$h" ] || open_stop "$k" "the record of the deleted worktree holds a commit made on a detached HEAD and left behind ${h:0:12} — removing the record loses it too. Whether to drop it is the user's call"
  done < <(reflog_orphans "$repo" "$id")
  common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
  while read -r ref h; do
    [ -z "$ref" ] || open_stop "$k" "the record of the deleted worktree holds $ref (${h:0:12}) — removing the record loses it too. Whether to drop it is the user's call"
  done < <(git --git-dir="$common/worktrees/$id" for-each-ref --format='%(refname) %(objectname)' refs/worktree/ 2>/dev/null)
}

# open_judge <name> (steps 5 and 6): every repo, the umbrella's docs git too, judged before anything is made.
# The repos of the side are the scope and every repo already holding the branch (merge picks repos by the
# branch, not by the scope). Sets OPEN_KEYS, OPEN_DO and OPEN_REC for open_make; prints each stop.
open_judge() {
  local name="$1" k repo sp state rec h side="$ROOT/.worktrees/$1" link
  OPEN_KEYS=() OPEN_DO=() OPEN_REC=()
  if ! git -C "$ROOT" check-ignore -q .worktrees/; then
    open_stop . ".worktrees/ not ignored — $ROOT/.gitignore needs a .worktrees/ line"
    return 1
  fi
  if [ "$MODE" = umbrella ] && has_branch "$ROOT" "$name"; then
    open_stop . "same-named branch that is not a side branch — the umbrella docs git holds no side branch$(fix_hint "$ROOT" "$name")"
  fi
  [ "$MODE" = single ] || open_name_free . "$ROOT" "$name"
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    sp=$(spot "$k" "$name")
    state=$(side_state "$k" "$name")
    case "$state" in
      none)
        open_name_free "$k" "$repo" "$name"
        h=$(merge_commits "$k" "$name" | head -n 1)
        [ -z "$h" ] || open_stop "$k" "name already used — main has 'chore(trunk): merge $name' ${h:0:12}. Add -2 to the plan file name"
        in_scope "$k" || continue
        if spot_taken "$sp"; then open_stop "$k" "something is already at the side branch spot: $sp"; else open_add "$k" create; fi
        ;;
      side)
        if [ "$MODE" = umbrella ] && [ -e "$sp/CLAUDE.md" ] && [ ! -L "$sp/CLAUDE.md" ]; then
          open_stop "$k" "not a symlink: $sp/CLAUDE.md — sessions would edit a copy instead of the canonical $repo/CLAUDE.md"
        fi
        open_add "$k" resume
        ;;
      half-made)
        if spot_taken "$sp"; then open_stop "$k" "something is already at the side branch spot: $sp"; else open_add "$k" worktree; fi
        ;;
      prunable)
        rec=$(branch_record "$repo" "$name")
        rec=${rec#*$'\t'}
        open_prunable "$k" "$rec"
        if spot_taken "$sp"; then open_stop "$k" "something is already at the side branch spot: $sp"; else open_add "$k" record "$rec"; fi
        ;;
      *) open_stop "$k" "same-named branch that is not a side branch — $(not_side_why "$k" "$name" "$state")" ;;
    esac
  done
  if [ "$MODE" = umbrella ]; then
    for link in docs CONTEXT.md; do
      if [ -e "$side/$link" ] && [ ! -L "$side/$link" ]; then
        open_stop . "not a symlink: $side/$link — sessions would edit a copy instead of the umbrella's canonical one"
      fi
    done
  fi
  [ "${OPEN_STOPPED:-0}" -eq 0 ]
}

open_name_free() { # <key> <repo> <name>: no branch under <name>/, which keeps git from making <name>
  local sub
  sub=$(git -C "$2" for-each-ref --format='%(refname:lstrip=2)' "refs/heads/$3/" | paste -sd' ' -)
  [ -z "$sub" ] || open_stop "$1" "$3/… branches — with $sub there, the branch $3 cannot be made"
}

# recent <key> <name>: the side saw a commit of its own, or its worktree a file change, in the last 30 minutes.
recent() {
  local t sp
  t=$(git -C "$(repo_dir "$1")" log -1 --format=%ct "refs/heads/$2" ^refs/heads/main 2>/dev/null)
  if [ -n "$t" ] && [ $(($(date +%s) - t)) -lt 1800 ]; then return 0; fi
  sp=$(spot "$1" "$2")
  [ -n "$(find "$sp" -name .git -prune -o -mmin -30 -print -quit 2>/dev/null)" ]
}

open_git() { # <key> <what> <git args...>: runs git in that repo; a failure stops open, and a rerun picks up
  local k="$1" what="$2" out
  shift 2
  out=$(git -C "$(repo_dir "$k")" "$@" 2>&1) && return 0
  open_stop "$k" "$what failed — ${out%%$'\n'*} · fix it, then rerun open to resume"
  return 1
}

# open_make <name> (step 7): branches, markers and worktrees, by the short name from refs/heads/main.
open_make() {
  local name="$1" i k sp start
  for ((i = 0; i < ${#OPEN_KEYS[@]}; i++)); do
    k=${OPEN_KEYS[$i]}
    sp=$(spot "$k" "$name")
    case "${OPEN_DO[$i]}" in
      resume)
        if recent "$k" "$name"; then
          echo "$k: resumed — $sp · recent activity (a commit or file change in the last 30 minutes): another session may be working in this side branch"
        else
          echo "$k: resumed — $sp"
        fi
        ;;
      record)
        open_git "$k" "clearing the deleted worktree's record" worktree remove "${OPEN_REC[$i]}" || return 1
        open_git "$k" "git worktree add" worktree add -q "$sp" "$name" || return 1
        echo "$k: cleared the deleted worktree's record and added only the worktree — $sp"
        ;;
      worktree)
        open_git "$k" "git worktree add" worktree add -q "$sp" "$name" || return 1
        echo "$k: added only the worktree — $sp"
        ;;
      create)
        open_git "$k" "git branch" branch "$name" refs/heads/main || return 1
        start=$(git -C "$(repo_dir "$k")" rev-parse "refs/heads/$name")
        open_git "$k" "side branch marker" config "branch.$name.trunk" "$start" || return 1
        open_git "$k" "git worktree add" worktree add -q "$sp" "$name" || return 1
        echo "$k: created — branch $name · side branch marker ${start:0:12} · worktree $sp"
        ;;
    esac
  done
}

# open_links <name> (step 8, umbrella): the three links of every repo of the side, each made only when absent.
open_links() {
  local name="$1" side="$ROOT/.worktrees/$1" k made="" p
  [ "$MODE" = umbrella ] || return 0
  for k in ${OPEN_KEYS[@]+"${OPEN_KEYS[@]}"}; do
    p="$(spot "$k" "$name")/CLAUDE.md"
    if [ ! -e "$p" ] && [ ! -L "$p" ]; then
      ln -s "../../../$UMB-$k/CLAUDE.md" "$p" && made="${made:+$made · }${p#"$ROOT"/}"
    fi
  done
  for p in docs CONTEXT.md; do
    if [ ! -e "$side/$p" ] && [ ! -L "$side/$p" ]; then
      ln -s "../../$p" "$side/$p" && made="${made:+$made · }.worktrees/$name/$p"
    fi
  done
  [ -z "$made" ] || echo "Links filled in: $made"
}

# open_env <name>: a new worktree has none of the main checkout's ignored files, so a dev server or e2e that reads
# .env* fails to start there. Each repo of the side gets the ignored .env* files of its main checkout that it lacks,
# only where the worktree ignores that path too; never .env.example (no secret) or .env.production* (prod secrets stay
# out of side folders). Only paths are printed, never a value. tidy keeps a worktree whose copy no longer matches.
open_env() {
  local name="$1" k repo sp f made="" kept=""
  for k in ${OPEN_KEYS[@]+"${OPEN_KEYS[@]}"}; do
    repo=$(repo_dir "$k")
    sp=$(spot "$k" "$name")
    while IFS= read -r -d '' f; do
      # git lists a nested repo, the side worktree itself among them, as one folder entry no pathspec excludes
      case "$f" in */) continue ;; esac
      [ ! -e "$sp/$f" ] && [ ! -L "$sp/$f" ] || continue
      if ! git -C "$sp" check-ignore -q -- "$f"; then
        kept="${kept:+$kept · }${sp#"$ROOT"/}/$f"
        continue
      fi
      mkdir -p "$(dirname "$sp/$f")" && cp -p "$repo/$f" "$sp/$f" && made="${made:+$made · }${sp#"$ROOT"/}/$f"
    done < <(git -C "$repo" ls-files -z -o -i --exclude-standard -- ':(glob)**/.env*' ':(exclude,glob)**/.env.example' \
      ':(exclude,glob)**/.env.production*' ':(exclude,glob)**/node_modules/**' ':(exclude,glob).worktrees/**')
  done
  [ -z "$made" ] || echo "env copied: $made"
  [ -z "$kept" ] || echo "env not copied (the side worktree does not ignore it): $kept"
}

# open_notices (umbrella): a repo whose Makefile or package.json reads ../<umbrella>-<unit>/ of a
# sibling, with only one of the two on the side, gets one line.
open_notices() {
  local a b files f
  [ "$MODE" = umbrella ] || return 0
  for a in "${KEYS[@]}"; do
    files=()
    for f in Makefile package.json; do [ ! -f "$(repo_dir "$a")/$f" ] || files+=("$(repo_dir "$a")/$f"); done
    [ "${#files[@]}" -gt 0 ] || continue
    for b in "${KEYS[@]}"; do
      [ "$b" != "$a" ] && grep -qF -- "../$UMB-$b/" "${files[@]}" || continue
      if open_has "$a" && ! open_has "$b"; then
        echo "Note: $a's sibling checks SKIP here and run at merge ②. To change $b, open $b in this side branch too"
      elif open_has "$b" && ! open_has "$a"; then
        echo "Note: to change $b, open $a in this side branch too"
      fi
    done
  done
}

open_has() { local k; for k in ${OPEN_KEYS[@]+"${OPEN_KEYS[@]}"}; do [ "$k" != "$1" ] || return 0; done; return 1; } # <key>

# entry_screen <plan>: what to see before a side opens, never saved: this milestone and its sides,
# what earlier ones left, every open side, the plan's ledger ids with their closing lines, the stale facts. It
# reuses the short map's lines; at most 40 lines.
entry_screen() {
  echo "Entry — what to see before opening (not saved)"
  map_load
  short_milestones
  short_bundle
  entry_left
  short_open
  entry_ledger "$1"
  short_footer
}

entry_left() { # what earlier work left: commits and stashes no plan will merge, closed sides not tidied
  local missing tidy
  missing=$(short_missing)
  tidy=$(tidy_rows | awk -F'\t' '
    $1 == "ok" { ok = ok (ok == "" ? "" : ", ") $2; next }
    { kept = kept (kept == "" ? "" : ", ") $2 }
    END {
      if (ok != "") s = "can remove " ok
      if (kept != "") s = s (s == "" ? "" : " · ") "kept " kept
      if (s != "") print "To tidy: " s " (bash scripts/trunk.sh tidy)"
    }')
  if [ -z "$missing$tidy" ]; then
    echo "Left from earlier milestones: none"
    return 0
  fi
  echo "Left from earlier milestones"
  [ -z "$missing" ] || printf '%s\n' "$missing" | sed 's/^/  /'
  [ -z "$tidy" ] || echo "  $tidy"
}

entry_ledger() { # <plan>: the ledger ids the plan names with their state cells: a closed one is seen before it is redone
  local rows n
  rows=$(ledger_ids "$1")
  if [ -z "$rows" ]; then
    echo "Ledger: no ID this plan points to"
    return 0
  fi
  printf '%s\n' "$rows" | head -n "$ENTRY_LEDGER_CAP" | awk -F'\t' '{ print "Ledger " $1 ": " $2 }'
  n=$(printf '%s\n' "$rows" | wc -l | tr -d ' ')
  [ "$n" -le "$ENTRY_LEDGER_CAP" ] || echo "Ledger, $((n - ENTRY_LEDGER_CAP)) more — bash scripts/trunk.sh status"
}

open_report() { # <name>: the side folder, each repo's worktree and the plan's absolute path, last
  local k
  echo "Side branch folder: $ROOT/.worktrees/$1"
  for k in ${OPEN_KEYS[@]+"${OPEN_KEYS[@]}"}; do
    if [ "$MODE" = single ]; then echo "Worktree: $(spot "$k" "$1")"; else echo "Worktree $k: $(spot "$k" "$1")"; fi
  done
  echo "plan: $OPEN_PLAN"
}

cmd_open() { # <name>
  local name="$1"
  OPEN_STOPPED=0
  echo "trunk.sh open · $ROOT"
  refuse_place
  refuse_heavy
  open_name_ok "$name"
  lock_take "open $name"
  open_plan "$name" || exit 1
  entry_screen "$OPEN_PLAN"
  open_scope "$OPEN_PLAN" || exit 1
  open_judge "$name" || exit 1
  open_make "$name" || exit 1
  open_links "$name"
  open_env "$name"
  open_notices
  open_report "$name"
}
