# trunk.sh merge <name> [--partial], sourced by trunk.sh: steps 1, 2, 5, 6 and 8, the merge record and
# the report; steps 3, 4 and 7 are in integrate.sh. main moves only in step 6, so a stop before it changes nothing.
# The run's state: M_NAME, M_PARTIAL, M_PLAN, M_REVIEW (the plan's Review: field at step 2), M_SIDE (the repos holding
# the branch, in key order), M_MERGE (those with side commits), the maps M_MARKS (review hash) and M_COUNTS (side
# commits) of the repos to merge, M_NOTES (lines only reported), M_TAG (names this run's logs), M_TMP (1 while a
# temp place may exist) and M_STOPPED.

merge_stop() { echo "Stop: $1: $2"; M_STOPPED=1; } # <key> <reason>

wt_fault_text() { # <wt_faults line> <name>: the words of one broken side worktree condition
  case "$1" in
    head) echo "HEAD is not refs/heads/$2 (detached or another branch) — commits made on a detached HEAD vanish when the worktree is removed" ;;
    op:*) echo "operation ${1#op:} in progress" ;;
    dirty) echo "uncommitted changes or untracked files" ;;
    stash:*) echo "stash of this branch: ${1#stash:}" ;;
    loose-stash:*) echo "branchless stash ${1#loose-stash:} — whether to move it with git stash branch or drop it is the user's call" ;;
    *) echo "$1" ;;
  esac
}

# merge_log <name>: from here on the output goes to the log as well. tee runs on a process
# substitution, so the merge stays in this process and a TERM still reaches the cleanup trap. tee ignores SIGPIPE:
# when the reader of the output goes away (merge x | head), it keeps logging, so this shell's writes never kill it
# before the cleanup. Its stderr is dropped, or each later line would print a broken pipe warning.
merge_log() {
  local log
  M_TAG="${1//\//_}-$(date +%Y%m%d-%H%M%S)"
  log="$STATE_DIR/logs/merge-$M_TAG.log"
  mkdir -p "$STATE_DIR/logs" || exit 2
  echo "trunk.sh merge · $ROOT" >>"$log"
  exec > >(trap '' PIPE; exec tee -a "$log" 2>/dev/null) 2>&1
  echo "Log: $log"
}

# merge_plan <name> (step 2): the plan head, read from the root's working tree: one plan, not dropped or superseded, no
# Waiting: or On hold:, the milestone check and, unless --partial, no open box. 1 when there is no single
# plan to read or it is dropped.
merge_plan() {
  local plans rc v
  plans=$(plan_for "$1")
  rc=$?
  case "$rc" in
    0) ;;
    1)
      merge_stop . "no plan — no plan in docs/plans/ or docs/archive/ has 'Side branch: $1' in its head"
      return 1
      ;;
    *)
      merge_stop . "two or more plans — $(printf '%s\n' "$plans" | paste -sd' ' -)"
      return 1
      ;;
  esac
  M_PLAN=$plans
  # Dropped or replaced work never goes to main without the user. A plan closed as done before its merge passes.
  v=$(plan_field "$M_PLAN" state)
  case "$v" in
    dropped* | superseded*)
      merge_stop . "plan closed — $M_PLAN ($v). Dropped or superseded work is not merged. Whether to drop the side branch or reopen the plan is the user's call"
      return 1
      ;;
  esac
  M_REVIEW=$(plan_field "$M_PLAN" review)
  v=$(plan_field "$M_PLAN" wait)
  v=${v%%$'\n'*}
  [ -z "$v" ] || merge_stop . "Waiting: $v — merge once the wait is lifted"
  v=$(plan_field "$M_PLAN" hold)
  v=${v%%$'\n'*}
  [ -z "$v" ] || merge_stop . "On hold: $v — merge once the hold is removed"
  v=$(milestone_gate "$M_PLAN") || merge_stop . "$v"
  v=$(open_boxes "$M_PLAN")
  if [ "$M_PARTIAL" -eq 0 ] && [ "$v" != 0 ]; then
    merge_stop . "${v} open task(s) (a code block that never closes counts as one too) — the final merge comes at 0 open tasks. To ship what is done so far first, --partial"
  fi
  return 0
}

# side_repo_checks <key> <name> (step 2): what every side repo must hold, with side commits or without: the side
# worktree conditions, in an umbrella the worktree's CLAUDE.md a link, in a single repo no change to
# the docs only main edits (a three-dot diff: two dots would blame the side for docs main added after the side
# merged main), and the main checkout on main.
side_repo_checks() {
  local k="$1" name="$2" repo wt line docs head
  repo=$(repo_dir "$k")
  wt=$(spot "$k" "$name")
  while IFS= read -r line; do merge_stop "$k" "worktree $(wt_fault_text "$line" "$name")"; done < <(wt_faults "$wt" "$name")
  if [ "$MODE" = umbrella ] && [ -e "$wt/CLAUDE.md" ] && [ ! -L "$wt/CLAUDE.md" ]; then
    merge_stop "$k" "CLAUDE.md not a symlink: $wt/CLAUDE.md — a session may have edited a copy instead of the canonical $repo/CLAUDE.md. Move the edited lines to the canonical one and turn it back into a link"
  fi
  if [ "$MODE" = single ]; then
    docs=$(git -C "$repo" diff --name-only "refs/heads/main...refs/heads/$name" -- docs/ CLAUDE.md CONTEXT.md | paste -sd' ' -)
    [ -z "$docs" ] || merge_stop "$k" "docs only main edits — the side branch edited $docs. Edit docs in the main checkout"
  fi
  head=$(git -C "$repo" symbolic-ref -q HEAD || echo detached)
  [ "$head" = refs/heads/main ] || merge_stop "$k" "main checkout HEAD is $head — it must be refs/heads/main"
}

# review_check <key> <name> (step 2): a repo with side commits has its review hash once in the side
# line, the hash resolves, and it is the side's tip now. Step 3 merges that hash, not the branch.
review_check() {
  local k="$1" name="$2" repo h rc full tip form="<hash>"
  repo=$(repo_dir "$k")
  [ "$k" = . ] || form="$k@<hash>"
  h=$(review_hash "$M_PLAN" "$k")
  rc=$?
  case "$rc" in
    0) ;;
    1)
      merge_stop "$k" "no review mark — once the review is clean, write 'Review: $form' in the side branch line"
      return 0
      ;;
    *)
      merge_stop "$k" "review mark twice — $(printf '%s\n' "$h" | paste -sd' ' -)"
      return 0
      ;;
  esac
  if ! full=$(git -C "$repo" rev-parse -q --verify "$h^{commit}"); then
    merge_stop "$k" "review mark does not resolve — $h"
    return 0
  fi
  tip=$(git -C "$repo" rev-parse "refs/heads/$name")
  if [ "$full" != "$tip" ]; then
    merge_stop "$k" "review mark differs from the side branch tip — mark ${full:0:12}, tip ${tip:0:12}. Review the changed range, fix the mark, then run again"
    return 0
  fi
  M_MARKS="$M_MARKS$k $full"$'\n'
}

detached_at_spot() { # <key> <name>: a live worktree on a detached HEAD sits at that side spot
  local st br p
  while IFS=$'\t' read -r st br p; do
    if [ "$st" = ok ] && [ "$br" = - ] && at_spot "$p" "$1" "$2"; then return 0; fi
  done < <(wt_list "$(repo_dir "$1")")
  return 1
}

# merge_sides <name> (step 2): the side's repos come from git, by the branch name, never by the scope, so none is
# left out; every repo holding a branch of that name must hold a side (the umbrella's docs git holds none). A
# scope repo without the branch is only reported. Sets M_SIDE, M_MERGE, M_MARKS, M_COUNTS and M_NOTES.
merge_sides() {
  local name="$1" k repo state n scope=""
  M_SIDE="" M_MERGE="" M_MARKS="" M_COUNTS="" M_NOTES=""
  if [ "$MODE" = umbrella ]; then
    if has_branch "$ROOT" "$name"; then
      merge_stop . "same-named branch that is not a side branch — the umbrella docs git holds no side branch$(fix_hint "$ROOT" "$name")"
    fi
    scope=$(plan_field "$M_PLAN" scope)
    scope=${scope//+/ }
    if in_words all "$scope"; then scope="${KEYS[*]}"; fi
  fi
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    if ! has_branch "$repo" "$name"; then
      if [ "$MODE" = umbrella ] && in_words "$k" "$scope"; then
        M_NOTES="$M_NOTES$k: no branch — in the scope, but it has no branch of this name, so it is not merged (reported only)"$'\n'
      fi
      continue
    fi
    M_SIDE="${M_SIDE:+$M_SIDE }$k"
    state=$(side_state "$k" "$name")
    # A side worktree on a detached HEAD has no branch to be found by, so side_state sees no worktree; it is
    # the side's own worktree with a broken condition.
    if [ "$state" = half-made ] && detached_at_spot "$k" "$name"; then state=side; fi
    if [ "$state" != side ]; then
      merge_stop "$k" "same-named branch that is not a side branch — $(not_side_why "$k" "$name" "$state")"
      continue
    fi
    side_repo_checks "$k" "$name"
    n=$(ahead "$k" "$name")
    [ "${n:-0}" -gt 0 ] || continue
    M_MERGE="${M_MERGE:+$M_MERGE }$k"
    M_COUNTS="$M_COUNTS$k $n"$'\n'
    review_check "$k" "$name"
  done
}

# merge_nothing <name> (end of step 2): no repo has side commits. A merge record, or a merge commit of the name on
# a side repo's main first-parent line, means all of it is in already (0); else there is nothing to merge (1),
# shown with any suspect commit of the side on main.
merge_nothing() {
  local name="$1" k merged=0 line
  if [ -f "$(rec_file "$name")" ]; then
    merged=1
  else
    scan_tables
    for k in $M_SIDE; do
      if [ -n "$(scan_merges "$k" "$name")" ]; then merged=1; fi
    done
  fi
  if [ "$merged" -eq 1 ]; then
    rec_clear "$name"
    echo "Already all in — every side branch commit of $name is on main"
    return 0
  fi
  echo "No commits to merge — 0 side branch commits, and neither a record of this name nor a merge commit of it on main"
  while IFS=$'\t' read -r k line; do
    echo "  Suspect: $k $line — a commit with 'Ref: $name' is on main. Check whether side branch work was committed on main"
  done < <(suspects "$name")
  return 1
}

rec_file() { printf '%s\n' "$STATE_DIR/merge-$1.rec"; } # <name>
rec_clear() { rm -f "$(rec_file "$1")"; }               # <name>

# rec_write <name> (step 6): '<key> <old main> <temp tip>' for each repo to merge. The line of a repo
# already raised stays as it is, so the report keeps its first main and no other session's commits mix in. 1 when
# the record could not be written in full; the old record, if any, stays.
rec_write() {
  local f raised k line bad=0
  f=$(rec_file "$1")
  raised=$(rec_raised "$1" | paste -sd' ' -)
  {
    if [ -f "$f" ]; then
      while IFS= read -r line; do
        if in_words "${line%% *}" "$raised"; then printf '%s\n' "$line" || bad=1; fi
      done <"$f"
    fi
    for k in $M_MERGE; do
      in_words "$k" "$raised" || printf '%s %s %s\n' "$k" "$(map_get "$INT_BASE" "$k")" "$(map_get "$INT_TIP" "$k")" || bad=1
    done
    [ "$bad" -eq 0 ]
  } >"$f.new" && mv "$f.new" "$f" && return 0
  rm -f "$f.new"
  return 1
}

rec_keep_raised() { # <name>: drops the lines of repos not raised, and the record with them when none is left
  local f raised line kept=""
  f=$(rec_file "$1")
  [ -f "$f" ] || return 0
  raised=$(rec_raised "$1" | paste -sd' ' -)
  while IFS= read -r line; do
    if in_words "${line%% *}" "$raised"; then kept="$kept$line"$'\n'; fi
  done <"$f"
  if [ -z "$kept" ]; then rm -f "$f"; else printf '%s' "$kept" >"$f"; fi
}

# merge_recheck <name> (step 5, ① right before main moves): the same side and merge repos as step 2, every side
# worktree still keeping its conditions, each tip still its review hash, and no side commit outside the
# integration. A side that moved means the review mark is stale: review the change, fix the mark, run again.
merge_recheck() {
  local name="$1" k repo side="" merge="" line tip n
  for k in "${KEYS[@]}"; do
    has_branch "$(repo_dir "$k")" "$name" || continue
    side="${side:+$side }$k"
    [ "$(ahead "$k" "$name")" = 0 ] || merge="${merge:+$merge }$k"
  done
  if [ "$side" != "$M_SIDE" ] || [ "$merge" != "$M_MERGE" ]; then
    merge_stop . "side branch repos changed — at step 2 side ${M_SIDE:-none} · to merge ${M_MERGE:-none}, now side ${side:-none} · to merge ${merge:-none}"
  fi
  for k in $M_SIDE; do
    while IFS= read -r line; do merge_stop "$k" "worktree $(wt_fault_text "$line" "$name")"; done < <(wt_faults "$(spot "$k" "$name")" "$name")
  done
  for k in $M_MERGE; do
    repo=$(repo_dir "$k")
    tip=$(git -C "$repo" rev-parse -q --verify "refs/heads/$name")
    if [ "$tip" != "$(map_get "$M_MARKS" "$k")" ]; then
      merge_stop "$k" "review mark differs from the side branch tip — the side branch moved to ${tip:0:12} after the integration. Review the changed range, fix the mark, then run again"
    fi
    n=$(git -C "$repo" rev-list --count "refs/heads/$name" "^$(map_get "$INT_TIP" "$k")" 2>/dev/null)
    [ "$n" = 0 ] || merge_stop "$k" "${n:-?} side branch commit(s) not in the integration"
  done
  [ "$M_STOPPED" -eq 0 ]
}

# retry_lock <command...>: runs it, and again up to four times a second apart while it fails on an index.lock
# (another session's git). Prints the output of the last try.
retry_lock() {
  local out i
  for i in 1 2 3 4 5; do
    if out=$("$@" 2>&1); then
      [ -z "$out" ] || printf '%s\n' "$out"
      return 0
    fi
    case "$out" in *index.lock*) ;; *) break ;; esac
    [ "$i" -eq 5 ] || sleep 1
  done
  printf '%s\n' "$out"
  return 1
}

# added_blocked <repo> <tip>: the paths tip adds to main (a renamed path counts as added) that the main checkout
# holds untracked: the path or a leading part of it as a file or link git does not track, or the path as a folder
# with untracked or ignored files in it. The dry run lets an ignored file be overwritten. A tracked file whose name
# differs only in case is that same file on a case-blind disk.
added_blocked() {
  local repo="$1" p q part
  local -a parts
  while IFS= read -r -d '' p; do
    q=""
    IFS=/ read -r -a parts <<<"$p"
    for part in "${parts[@]}"; do
      q=${q:+$q/}$part
      if [ -L "$repo/$q" ] || { [ -e "$repo/$q" ] && [ ! -d "$repo/$q" ]; }; then
        [ -n "$(git -C "$repo" ls-files -- ":(icase,literal)$q")" ] || { echo "$q"; break; }
      elif [ "$q" = "$p" ] && [ -d "$repo/$q" ] && [ -n "$(git -C "$repo" ls-files -o -- ":(literal)$q")" ]; then
        echo "$q"
      fi
    done
  done < <(git -C "$repo" diff --name-only --no-renames --diff-filter=A -z refs/heads/main "$2")
}

# ff_dry_run <repo> <tip>: the fast-forward's verdict without doing it. The index's file stats are refreshed first,
# as git merge does: a file whose stat changed but whose content did not would read as a local change.
ff_dry_run() {
  git -C "$1" update-index -q --refresh >/dev/null 2>&1
  git -C "$1" read-tree -n -m -u refs/heads/main "$2"
}

# main_checkout_ready <key> (step 6): that repo's main checkout takes the fast-forward: HEAD on main, nothing in
# progress or unmerged, the dry run of the merge (the same verdict as the real one; no file changes and the index
# only gets its file stats refreshed) passes, and no added path is blocked. Every finding is reported: the dry run
# stops at its first error.
main_checkout_ready() {
  local k="$1" repo tip head item out p
  repo=$(repo_dir "$k")
  tip=$(map_get "$INT_TIP" "$k")
  head=$(git -C "$repo" symbolic-ref -q HEAD || echo detached)
  if [ "$head" != refs/heads/main ]; then
    merge_stop "$k" "main checkout HEAD is $head — it must be refs/heads/main"
    return 0
  fi
  for item in $(in_progress "$repo"); do merge_stop "$k" "operation $item in progress in the main checkout — finish or abort it, then run again"; done
  out=$(git -C "$repo" ls-files -u | cut -f2 | sort -u | paste -sd' ' -)
  [ -z "$out" ] || merge_stop "$k" "unresolved entries in the main checkout — $out"
  if ! out=$(retry_lock ff_dry_run "$repo" "$tip"); then
    merge_stop "$k" "main checkout cannot take it — $(printf '%s\n' "$out" | grep -m 3 -E '^(error|fatal):' | paste -sd' ' -)"
  fi
  while IFS= read -r p; do
    merge_stop "$k" "path to be added $p — the main checkout holds it as an untracked file · symlink · ignored file (inside it, for a folder). Move or delete it, then run again"
  done < <(added_blocked "$repo" "$tip")
}

# merge_ready <name> (step 6, before any repo moves): the plan head again from the working tree (git show would
# miss an edit not committed), every main of the placement where step 3 found it (else 4: back to step 3), and
# each main checkout to raise. Any other stop is 1 without a record: a rerun would stop the same way.
merge_ready() {
  local name="$1" k v moved=""
  v=$(plan_field "$M_PLAN" wait)
  v=${v%%$'\n'*}
  [ -z "$v" ] || merge_stop . "Waiting: $v — added to the plan head during the run"
  v=$(plan_field "$M_PLAN" hold)
  v=${v%%$'\n'*}
  [ -z "$v" ] || merge_stop . "On hold: $v — added to the plan head during the run"
  if [ "$(plan_field "$M_PLAN" review)" != "$M_REVIEW" ]; then
    merge_stop . "review mark changed — the Review: field of the plan head changed during the run. Run merge again"
  fi
  [ "$M_STOPPED" -eq 0 ] || return 1
  for k in $(batch_keys); do
    [ "$(git -C "$(repo_dir "$k")" rev-parse refs/heads/main)" = "$(map_get "$INT_BASE" "$k")" ] || moved="${moved:+$moved }$k"
  done
  if [ -n "$moved" ]; then
    echo "main moved: $moved — again from step 3 (integration · ②)"
    return 4
  fi
  for k in $M_MERGE; do main_checkout_ready "$k"; done
  [ "$M_STOPPED" -eq 0 ] || return 1
}

# merge_raise <name> (step 6): the record, then each repo's main fast-forwarded to its temp tip. No main moves
# without the record: a half merge must be found again. A fast-forward that fails before this run raised any repo
# goes back to step 3 when that main moved (4), or stops without a record (1). Once a repo was raised it is a half
# merge (3): a raised repo is never undone.
merge_raise() {
  local name="$1" k repo tip out raised=""
  if ! rec_write "$name"; then
    merge_stop . "could not write the record — $(rec_file "$name"). main is unchanged. Check the disk space and the write permission of that folder, then run again"
    return 1
  fi
  for k in $M_MERGE; do
    repo=$(repo_dir "$k")
    tip=$(map_get "$INT_TIP" "$k")
    if out=$(retry_lock git -C "$repo" merge -q --ff-only --no-overwrite-ignore "$tip") \
      && [ "$(git -C "$repo" rev-parse refs/heads/main)" = "$tip" ]; then
      raised="${raised:+$raised }$k"
      continue
    fi
    if [ -z "$raised" ] && [ "$(git -C "$repo" rev-parse refs/heads/main)" != "$(map_get "$INT_BASE" "$k")" ]; then
      rec_keep_raised "$name"
      echo "main moved: $k — no repo raised yet, so again from step 3 (integration · ②)"
      return 4
    fi
    raised=$(rec_raised "$name" | paste -sd' ' -)
    if [ -z "$raised" ]; then
      rec_clear "$name"
      merge_stop "$k" "could not raise main — $(printf '%s\n' "$out" | head -n 2 | paste -sd' ' -). main is unchanged. Check the main checkout with git -C $(sh_quote "$repo") status (when a hook refuses the main update, the side branch files stay staged)"
      return 1
    fi
    merge_half "$name" "$raised"
    return 3
  done
  return 0
}

merge_mains() { # <record lines>: '<key>: main <before>..<after>' for each repo the record raised
  local k old tip
  while read -r k old tip; do
    [ -z "$k" ] || echo "$k: main ${old:0:12}..${tip:0:12}"
  done <<<"$1"
}

merge_half() { # <name> <raised keys>: the half merge; the plan stays open
  local name="$1" raised="$2" k old tip not="" up=""
  while read -r k old tip; do
    [ -n "$k" ] || continue
    if in_words "$k" "$raised"; then up="$up$k $old $tip"$'\n'; else not="${not:+$not }$k"; fi
  done <"$(rec_file "$name")"
  echo "Half merged: ${raised// / · } raised, ${not// / · } not raised"
  merge_mains "$up"
  for k in $not; do
    echo "  $k: check git status of the main checkout of the repo not raised — git -C $(sh_quote "$(repo_dir "$k")") status. When a hook refuses the main update, the side branch files stay staged"
  done
  echo "Next: once fixed, running merge again merges only the repos left. Leave the plan open"
}

# merge_report <name> <record lines> (step 8): each side repo's merged commits or why it was skipped, the scope
# repos without the branch, and each raised main before..after.
merge_report() {
  local name="$1" k n
  echo "Merged: $name$([ "$M_PARTIAL" -eq 0 ] || echo ' (--partial)')"
  for k in $M_SIDE; do
    if n=$(map_get "$M_COUNTS" "$k"); then
      echo "$k: ${n} commit(s)"
      git -C "$(repo_dir "$k")" log --format='  %h %s' "$(map_get "$M_MARKS" "$k")" "^$(map_get "$INT_BASE" "$k")"
    else
      echo "$k: skipped (0 side branch commits)"
    fi
  done
  printf '%s' "$M_NOTES"
  merge_mains "$2"
}

# merge_final <name> (step 8): main moved; every side repo is counted once more. A side commit off main, or a
# broken side worktree condition, ends it with 1 and the plan stays open.
merge_final() {
  local name="$1" k n left=0 bad=0 line
  for k in $M_SIDE; do
    n=$(ahead "$k" "$name")
    left=$((left + ${n:-0}))
  done
  if [ "$left" -gt 0 ]; then
    echo "${left} commit(s) left, plan not closed. Review the changed range, fix the review mark, then merge again"
    return 1
  fi
  for k in $M_SIDE; do
    while IFS= read -r line; do
      echo "$k: worktree $(wt_fault_text "$line" "$name"), plan not closed. Clean up or commit in the worktree, then run again"
      bad=1
    done < <(wt_faults "$(spot "$k" "$name")" "$name")
  done
  return "$bad"
}

merge_next() { # the next step after a merge, or after one found already done
  if [ "$M_PARTIAL" -eq 1 ]; then
    echo "Next: keep going on the side branch, the plan stays open"
  else
    echo "Next: close the plan, then bash scripts/trunk.sh tidy"
  fi
}

merge_tail() { # the end of every report: push stays with the user, the short map, the page reloaded if it is open
  echo "push stays with the user"
  cmd_short
  map_refresh_if_open --loaded # the scan cmd_short just made in this shell
}

merge_cleanup() { # step 7, once: the temp branch and places, when this run may have left any
  [ "$M_TMP" -eq 1 ] || return 0
  tmp_clear "$M_NAME"
  M_TMP=0
}

# merge_rounds <name>: steps 3 to 6, from step 3 again while a main moved before this run raised any. In a single
# repo, when the new integration differs from the verified one only in the docs main alone edits, only the docs
# gate runs again and the verify result is reused: frequent docs commits must not keep the merge going forever.
merge_rounds() {
  local name="$1" rc rows tip prev_tip="" prev_row=""
  while :; do
    tmp_clear "$name"
    M_TMP=1
    integrate "$name" || return 1
    tip=$(map_get "$INT_TIP" .)
    if [ -n "$prev_tip" ] && git -C "$ROOT" diff --quiet "$prev_tip" "$tip" -- . ':(exclude)docs' ':(exclude)CLAUDE.md' ':(exclude)CONTEXT.md'; then
      echo "verify reused — only docs changed on main, so the integrated tree outside the docs is the one verified at ②"
      rows="$prev_row"$'\n'"$(docs_gate "$name")"
    else
      rows=$(gate_batch "$name")
    fi
    gate_verdict "$rows" || return 1
    if [ "$MODE" = single ]; then
      prev_tip=$tip
      prev_row=$(printf '%s\n' "$rows" | awk -F'\t' -v d="$DOCS_KEY" '$1 != d')
    fi
    merge_recheck "$name" || return 1
    merge_ready "$name"
    rc=$?
    [ "$rc" -ne 4 ] || continue
    [ "$rc" -eq 0 ] || return 1
    merge_raise "$name"
    rc=$?
    [ "$rc" -eq 4 ] || return "$rc"
  done
}

cmd_merge() { # <name> [--partial]
  local name="$1" rc rec
  M_NAME=$name M_PARTIAL=0 M_STOPPED=0
  [ "${2:-}" != --partial ] || M_PARTIAL=1
  echo "trunk.sh merge · $ROOT"
  refuse_place
  refuse_heavy
  open_name_ok "$name"
  lock_take "merge $name"
  merge_log "$name"
  merge_plan "$name" && merge_sides "$name"
  [ "$M_STOPPED" -eq 0 ] || exit 1
  if [ -z "$M_MERGE" ]; then
    merge_nothing "$name" || exit 1
    merge_next
    merge_tail
    exit 0
  fi
  M_TMP=0
  on_exit merge_cleanup
  merge_rounds "$name"
  rc=$?
  case "$rc" in
    0) ;;
    3)
      merge_cleanup
      merge_tail
      exit 3
      ;;
    *) exit 1 ;;
  esac
  rec=$(cat "$(rec_file "$name")")
  rec_clear "$name"
  merge_cleanup
  merge_report "$name" "$rec"
  if merge_final "$name"; then merge_next; else rc=1; fi
  merge_tail
  exit "$rc"
}
