# trunk.sh tidy: removes the side branches whose plan is closed, whose commits are all on main and
# whose worktrees hold nothing that removal would lose. Anything else stays and is reported with its reason.

# tidy_blockers <name>: '<key>: <reason>' for each condition that keeps the side; no output means it may go.
# The plan comes first: a side just opened has no commits, so it looks merged and clean.
tidy_blockers() {
  local name="$1" plan k repo wt state n id line
  plan=$(plan_for "$name")
  case $? in
    0) ;;
    1) echo ".: no plan"; return 0 ;;
    *) echo ".: two or more plans"; return 0 ;;
  esac
  plan_closed "$plan" || { echo ".: plan open"; return 0; }
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    has_branch "$repo" "$name" || continue
    state=$(side_state "$k" "$name")
    case "$state" in
      side) ;;
      locked) echo "$k: worktree locked"; continue ;;
      *) echo "$k: not a side branch ($state)"; continue ;;
    esac
    wt=$(spot "$k" "$name")
    # git branch -d judges against HEAD, so the main checkout must be on main.
    [ "$(git -C "$repo" symbolic-ref -q HEAD)" = refs/heads/main ] || echo "$k: main checkout HEAD is not main"
    n=$(ahead "$k" "$name")
    if [ "$n" != 0 ] || ! git -C "$repo" merge-base --is-ancestor "refs/heads/$name" refs/heads/main; then
      echo "$k: ${n:-?} side branch commit(s) not on main"
    fi
    while IFS= read -r line; do echo "$k: worktree $line"; done < <(wt_faults "$wt" "$name")
    if ! id=$(wt_id "$repo" "$wt"); then
      echo "$k: could not find the worktree record"
    else
      while IFS= read -r line; do echo "$k: commit made on a detached HEAD and left behind ${line:0:12}"; done < <(reflog_orphans "$repo" "$id")
    fi
    while IFS= read -r line; do echo "$k: $line exists"; done < <(git -C "$wt" for-each-ref --format='%(refname)' refs/worktree/)
    # Hidden changes (skip-worktree, assume-unchanged) show in no status and vanish with the worktree.
    while IFS= read -r line; do echo "$k: hidden change $line"; done < <(git -C "$wt" ls-files -v | awk '$1 == "S" || $1 ~ /^[a-z]$/ { sub(/^[^ ]+ /, ""); print }')
    # Secrets cannot be committed, so an ignored .env* or *.local.json lost here is lost for good. Rebuildable
    # ignored files such as node_modules/ are not looked at.
    while IFS= read -r -d '' line; do
      cmp -s "$wt/$line" "$repo/$line" || echo "$k: protected ignored file $line differs from the main checkout"
    done < <(git -C "$wt" ls-files -z -o -i --exclude-standard -- ':(glob)**/.env*' ':(glob)**/*.local.json' \
      ':(exclude,glob)**/node_modules/**')
    # A resolvable upstream makes git branch -d judge against it instead of HEAD: the worktree would go and
    # the branch stay.
    line=$(git -C "$repo" rev-parse -q --verify "$name@{upstream}")
    if [ -n "$line" ] && ! git -C "$repo" merge-base --is-ancestor "refs/heads/$name" "$line"; then
      echo "$k: upstream does not hold the side branch tip"
    fi
  done
  tidy_nested "$name"
}

# Removing a worktree removes the worktrees nested in its folder too, with their uncommitted files.
tidy_nested() { # <name>
  local side k own st br p keys=("${KEYS[@]}")
  side=$(real_path "$ROOT/.worktrees/$1")
  [ "$MODE" = single ] || keys+=(.)
  for k in "${keys[@]}"; do
    own=""
    [ "$MODE" = umbrella ] && [ "$k" = . ] || own=$(real_path "$(spot "$k" "$1")")
    while IFS=$'\t' read -r st br p; do
      [ -e "$p" ] || continue
      p=$(real_path "$p")
      case "$p/" in "$side"/*) [ "$p" = "$own" ] || echo "$k: another worktree inside the side branch folder $p" ;; esac
    done < <(wt_list "$(repo_dir "$k")")
  done
}

tidy_kept() { # <name> <key>: <reason>; the key of a single repo (or of the plan) says nothing
  case "$2" in
    ".: "*) echo "Kept: $1 — ${2#.: }" ;;
    *) echo "Kept: $1 — $2" ;;
  esac
}

# Removes each repo's worktree, never by force, then its branch with git branch -d. A worktree that will not go
# (locked, or holding a submodule) keeps its branch. The umbrella links go only after every repo worktree went,
# and only as links.
tidy_remove() { # <name>
  local name="$1" k repo out side kept=0 link removed=""
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    has_branch "$repo" "$name" || continue
    if ! out=$(git -C "$repo" worktree remove "$(spot "$k" "$name")" 2>&1); then
      tidy_kept "$name" "$k: worktree remove failed — ${out%%$'\n'*}"
      kept=1
      continue
    fi
    if ! out=$(git -C "$repo" branch -d "$name" 2>&1); then
      tidy_kept "$name" "$k: branch -d failed — ${out%%$'\n'*}"
      kept=1
      continue
    fi
    removed="${removed:+$removed }$k"
  done
  [ "$kept" -eq 0 ] || [ -z "$removed" ] || tidy_kept "$name" ".: removed in the other repos: $removed"
  if [ "$MODE" = umbrella ] && [ "$kept" -eq 0 ]; then
    side="$ROOT/.worktrees/$name"
    for link in docs CONTEXT.md; do
      if [ -L "$side/$link" ]; then rm "$side/$link"; fi
    done
    if [ -d "$side" ] && ! rmdir "$side" 2>/dev/null; then
      tidy_kept "$name" ".: side branch folder not empty $side"
      kept=1
    fi
  fi
  [ "$kept" -eq 1 ] || echo "Removed: $name"
}

# Temp worktrees and branches of merges that died. Only called under the lock, so no merge is running.
tidy_sweep() {
  local k repo base st br p ref
  base=$(real_path "$TMP_ROOT")
  for k in "${KEYS[@]}"; do
    while IFS=$'\t' read -r st br p; do
      case "$(real_path "$p")/" in "$base"/?*) tmp_remove "$p" && echo "Removed temp: $p" ;; esac
    done < <(wt_list "$(repo_dir "$k")")
  done
  for p in "$TMP_ROOT"/*; do
    if [ -e "$p" ] || [ -L "$p" ]; then tmp_remove "$p"; fi
  done
  rmdir "$TMP_ROOT" 2>/dev/null
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    while IFS= read -r ref; do
      git -C "$repo" update-ref -d "$ref" && echo "Removed temp branch: $k ${ref#refs/heads/}"
    done < <(git -C "$repo" for-each-ref --format='%(refname)' refs/heads/trunk-tmp/)
  done
  return 0
}

# cmd_tidy: each side named in a plan head that has a branch in some repo is removed, or kept with its reasons.
cmd_tidy() {
  local name names=() k found lines line any=0
  echo "trunk.sh tidy · $ROOT"
  refuse_place
  refuse_heavy
  lock_take tidy
  tidy_sweep
  while IFS= read -r name; do [ -z "$name" ] || names+=("$name"); done < <(plan_sides | cut -f1 | sort -u)
  for name in ${names[@]+"${names[@]}"}; do
    found=0
    for k in "${KEYS[@]}"; do
      if has_branch "$(repo_dir "$k")" "$name"; then found=1; break; fi
    done
    [ "$found" -eq 1 ] || continue
    any=1
    lines=$(tidy_blockers "$name")
    # Checked again right before removing: the lock does not stop a session working in that side.
    [ -n "$lines" ] || lines=$(tidy_blockers "$name")
    if [ -n "$lines" ]; then
      while IFS= read -r line; do tidy_kept "$name" "$line"; done <<<"$lines"
    else
      tidy_remove "$name"
    fi
  done
  [ "$any" -eq 1 ] || echo "No side branch to tidy"
}
