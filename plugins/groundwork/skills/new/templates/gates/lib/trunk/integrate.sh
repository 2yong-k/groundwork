# trunk.sh merge, steps 3, 4 and 7, sourced by trunk.sh: the temp placement of the repos, each
# repo's install and verify or check, the docs gate, the diagnosis of a broken repo outside the side, and the
# cleanup. The temp branch is trunk-tmp/<name> and the placement <root>/.worktrees/.trunk-tmp/<name>/<repo folder>;
# the umbrella's docs git gets neither. The merge's state (M_*) is set by merge.sh.

TRUNK_HEAVY_GB=4 # the need-GB given to heavy.sh for install, verify and check alike
# The docs gate's row key: no repo key can take it (a unit is a folder name, with no '/'), not even a unit docs.
DOCS_KEY=docs/

# Maps are 'key value' lines: bash 3.2 has no associative arrays.
map_get() { # <map> <key>
  local k v
  while read -r k v; do
    if [ "$k" = "$2" ]; then
      printf '%s\n' "$v"
      return 0
    fi
  done <<<"$1"
  return 1
}

tmp_dir() { printf '%s\n' "$TMP_ROOT/$1/$(basename "$(repo_dir "$2")")"; } # <name> <key>: that repo's temp place

# batch_keys: the repos of the placement: those to merge in a single repo, every code repo in an umbrella.
batch_keys() { if [ "$MODE" = single ]; then echo "$M_MERGE"; else echo "${KEYS[*]}"; fi; }

# tmp_clear <name> (step 7, at exit whatever happened, and before a run): every temp worktree under the
# placement, detached ones too (they have no branch to find them by), the folder, and the temp branch.
tmp_clear() {
  local name="$1" k repo base st br p
  base="$(real_path "$TMP_ROOT")/$name"
  # A worktree add that died leaves its record locked, and worktree remove refuses a locked record.
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    while IFS=$'\t' read -r st br p; do
      case "$st $(real_path "$p")/" in "locked $base"/*) git -C "$repo" worktree unlock "$p" >/dev/null 2>&1 ;; esac
    done < <(wt_list "$repo")
  done
  tmp_remove "$TMP_ROOT/$name" # the folder, then each repo's records of it
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    if has_branch "$repo" "trunk-tmp/$name"; then git -C "$repo" update-ref -d "refs/heads/trunk-tmp/$name"; fi
  done
  rmdir "$TMP_ROOT" 2>/dev/null
  return 0
}

# integrate <name> (step 3): each repo to merge on trunk-tmp/<name> from its main, with the review hash of step 2
# merged in (--no-ff, so main's first-parent line gets one merge commit); in an umbrella every other repo
# detached at its main, so a gate that reads a sibling reads the merged result, never a main checkout. Sets
# INT_BASE (the main each repo was placed at) and INT_TIP (the integration commit of each repo to merge).
# Conflicts are listed per repo and undone, then it stops (1); the places go with the cleanup.
integrate() {
  local name="$1" k repo wt out files bad=0
  INT_BASE="" INT_TIP=""
  mkdir -p "$TMP_ROOT/$name" || return 1
  for k in $(batch_keys); do
    repo=$(repo_dir "$k")
    wt=$(tmp_dir "$name" "$k")
    if in_words "$k" "$M_MERGE"; then
      out=$(git -C "$repo" worktree add -q -b "trunk-tmp/$name" "$wt" refs/heads/main 2>&1)
    else
      out=$(git -C "$repo" worktree add -q --detach "$wt" refs/heads/main 2>&1)
    fi || {
      merge_stop "$k" "could not make the temp worktree — ${out%%$'\n'*}"
      return 1
    }
    INT_BASE="$INT_BASE$k $(git -C "$wt" rev-parse HEAD)"$'\n'
    in_words "$k" "$M_MERGE" || continue
    if out=$(git -C "$wt" merge -q --no-ff -m "chore(trunk): merge $name" -m "Ref: $name" "$(map_get "$M_MARKS" "$k")" 2>&1); then
      INT_TIP="$INT_TIP$k $(git -C "$wt" rev-parse HEAD)"$'\n'
      continue
    fi
    bad=1
    files=$(git -C "$wt" diff --name-only --diff-filter=U | paste -sd' ' -)
    if [ -n "$files" ]; then
      merge_stop "$k" "conflict — $files. In the side worktree, make the same combination with git merge main, fix it, then run again"
    else
      merge_stop "$k" "could not integrate — ${out%%$'\n'*}"
    fi
    git -C "$wt" merge --abort >/dev/null 2>&1
  done
  return "$bad"
}

# pick_port: a port in 20000-29999, away from the usual dev ports, that nothing answers on.
pick_port() {
  local i p
  for ((i = 0; i < 20; i++)); do
    p=$((20000 + RANDOM % 10000))
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

# gate_cmd <worktree> verify|check: the repo's install, then that target, run in the
# worktree with CI=1 (a running dev server is not reused) and a free E2E_PORT, through the repo's heavy.sh when it
# is the re-entrant one. Prints their output. Sets GATE_WHY to why it failed (empty when it passed) and GATE_NOTE
# to a line for the report. A 'SKIP: source not found' line fails it (a gate missed its sibling repo, so the
# placement is wrong; other SKIP lines are the project's own), and so does a tracked file the commands changed.
gate_cmd() {
  local wt="$1" target="$2" out="$1.out" head port rc=0 changed
  local -a install=() run=() wrap=()
  GATE_WHY="" GATE_NOTE=""
  if [ -f "$wt/pnpm-lock.yaml" ]; then
    if grep -qE "\"$target\"[[:space:]]*:" "$wt/package.json" 2>/dev/null; then
      install=(pnpm install --frozen-lockfile)
      run=(pnpm run "$target")
    fi
  elif [ -f "$wt/Makefile" ] && grep -qE "^$target:" "$wt/Makefile"; then
    if grep -qE '^install:' "$wt/Makefile"; then install=(make install); fi
    run=(make "$target")
  fi
  if [ "${#run[@]}" -eq 0 ]; then
    GATE_WHY="no $target — a pnpm repo has it as a package.json script, any other repo as the Makefile target $target"
    return 1
  fi
  if [ -f "$wt/scripts/heavy.sh" ]; then
    if grep -q HEAVY_SH_HELD "$wt/scripts/heavy.sh"; then
      wrap=(bash scripts/heavy.sh "$TRUNK_HEAVY_GB")
    else
      GATE_NOTE="old heavy.sh: not wrapped — it is not the re-entrant version (HEAVY_SH_HELD), so wrapping in it would stall the inner calls"
    fi
  fi
  if ! port=$(pick_port); then
    GATE_WHY="no free port — all 20 picked in 20000-29999 are in use"
    return 1
  fi
  head=$(git -C "$wt" rev-parse HEAD)
  (
    cd "$wt" || exit 1
    export CI=1 E2E_PORT="$port"
    if [ "${#install[@]}" -gt 0 ]; then ${wrap[@]+"${wrap[@]}"} "${install[@]}" || exit 3; fi
    ${wrap[@]+"${wrap[@]}"} "${run[@]}"
  ) </dev/null >"$out" 2>&1 || rc=$?
  cat "$out"
  changed=$(git -C "$wt" status --porcelain --untracked-files=no --ignore-submodules=none | cut -c4- | paste -sd' ' -)
  [ "$(git -C "$wt" rev-parse HEAD)" = "$head" ] || changed="${changed:+$changed }(HEAD moved)"
  case "$rc" in
    0) ;;
    3) GATE_WHY="install failed" ;;
    *) GATE_WHY="$target failed" ;;
  esac
  if [ -z "$GATE_WHY" ] && grep -q 'SKIP: source not found' "$out"; then
    GATE_WHY="SKIP: source not found — a gate could not find its sibling repo (the placement is wrong)"
  fi
  if [ -z "$GATE_WHY" ] && [ -n "$changed" ]; then GATE_WHY="tracked files changed — $changed"; fi
  [ -z "$GATE_WHY" ]
}

gate_log() { printf '%s\n' "$STATE_DIR/logs/gate-$M_TAG-$1.log"; } # <what>: the log of one gate of this run

gate_row() { # <key> <why, empty when it passed> <seconds> <log>
  local res=ok
  [ -z "$2" ] || res="fail:$2"
  printf '%s\t%s\t%s\t%s\n' "$1" "$res" "$3" "$4"
}

# docs_gate <name>: the docs gate of the integrated result (single repo) or of the umbrella's docs.
# No gate script is a failure, never a quiet pass. Prints its row, keyed DOCS_KEY.
docs_gate() {
  local base log t0=$SECONDS why=""
  if [ "$MODE" = single ]; then base=$(tmp_dir "$1" .); else base=$ROOT; fi
  log=$(gate_log docs)
  if [ ! -f "$base/scripts/check-docs.sh" ]; then
    why="no docs gate — there is no $base/scripts/check-docs.sh"
    echo "$why" >"$log"
  elif ! bash "$base/scripts/check-docs.sh" "$base/docs" </dev/null >"$log" 2>&1; then
    why="docs gate failed"
  fi
  gate_row "$DOCS_KEY" "$why" $((SECONDS - t0)) "$log"
}

# gate_batch <name> (step 4): each repo of the placement, verify for a repo to merge and check for any other,
# then the docs gate. One row per gate: '<key>\t<ok|fail:<reason>>\t<seconds>\t<log>'.
gate_batch() {
  local name="$1" k wt target t0
  for k in $(batch_keys); do
    wt=$(tmp_dir "$name" "$k")
    if in_words "$k" "$M_MERGE"; then target=verify; else target=check; fi
    t0=$SECONDS
    gate_cmd "$wt" "$target" >"$(gate_log "${wt##*/}-$target")" 2>&1
    [ -z "$GATE_NOTE" ] || echo "$k: $GATE_NOTE" >&2
    gate_row "$k" "$GATE_WHY" $((SECONDS - t0)) "$(gate_log "${wt##*/}-$target")"
  done
  docs_gate "$name"
}

# diagnose <key> (umbrella): a repo outside the side failed its check. It runs once more in a placement of every
# repo at its main (made once, beside the batch): failing there too, that main was broken already; passing, this
# side broke it. Either way the merge stops; it runs only on a failure, so the normal path costs nothing more.
diagnose() {
  local k="$1" d="$TMP_ROOT/$M_NAME/.diag" j
  if [ ! -d "$d" ]; then
    for j in "${KEYS[@]}"; do
      git -C "$(repo_dir "$j")" worktree add -q --detach "$d/$UMB-$j" refs/heads/main >/dev/null 2>&1
    done
  fi
  if [ ! -d "$d/$UMB-$k" ]; then
    echo "could not diagnose — could not make the placement of every repo at its main tip"
  elif gate_cmd "$d/$UMB-$k" check >"$(gate_log "diag-$UMB-$k-check")" 2>&1; then
    echo "this side branch broke $k — in the placement of every repo at its main tip, $k check passes"
  else
    echo "main already broken: $k — $k check fails in the placement of every repo at its main tip too. Fix $k's main first"
  fi
}

# gate_verdict <rows>: prints each result of step 4. A failure stops the merge with its reason, its log and the
# log's last lines (the docs gate: its FAIL lines); a repo outside the side gets its diagnosis. 1 on any failure.
gate_verdict() {
  local k res secs log what why bad=0
  while IFS=$'\t' read -r k res secs log; do
    [ -n "$k" ] || continue
    case "$k" in
      "$DOCS_KEY") what="docs gate" ;;
      *) if in_words "$k" "$M_MERGE"; then what="$k verify"; else what="$k check"; fi ;;
    esac
    if [ "$res" = ok ]; then
      echo "②: $what ok (${secs}s)"
      continue
    fi
    bad=1
    why=${res#fail:}
    if [ "$k" = "$DOCS_KEY" ]; then
      merge_stop . "$why — log $log"
      grep '^FAIL' "$log" | sed 's/^/  /'
      continue
    fi
    if [ "$MODE" = umbrella ] && ! in_words "$k" "$M_MERGE"; then why="$why · $(diagnose "$k" </dev/null)"; fi
    merge_stop "$k" "$why — log $log"
    tail -n 15 "$log" | sed 's/^/  /'
  done <<<"$1"
  return "$bad"
}
