# Scans of trunk.sh, sourced by it: every side branch with its class, mark, milestone, left-out count and flags,
# the ledger ids of a plan, stale facts, tags by day and suspect commits on main. Read only: it
# changes no repo. Columns of the tab-separated rows never hold an empty cell (an empty one is '-'), because
# read with a tab as the separator folds neighbouring tabs.

trunk_today() { printf '%s\n' "${TRUNK_TODAY:-$(date +%Y-%m-%d)}"; }

# ver_key <vX.Y.Z>: one number that orders versions.
ver_key() {
  local v="${1#v}" a b c
  a=${v%%.*}
  v=${v#*.}
  b=${v%%.*}
  c=${v#*.}
  echo $((a * 1000000 + b * 1000 + c))
}

# ms_scan: sets MS_ROWS (milestone rows, '-' for an empty cell), MS_OK (0 no board, 1 table read, 2 table
# unreadable), MS_FIRST (the earliest open version, or empty) and MS_THIS (this milestone: MS_FIRST, or the
# version after the table's highest one when none is open).
ms_scan() {
  local rows
  MS_ROWS="" MS_FIRST="" MS_THIS="" MS_OK=1
  if [ ! -f "$ROOT/docs/plans/status.md" ]; then
    MS_OK=0
    return 0
  fi
  if ! rows=$(milestones); then
    MS_OK=2
    return 0
  fi
  MS_ROWS=$(printf '%s\n' "$rows" | awk -F'\t' -v OFS='\t' '{ for (i = 1; i <= NF; i++) if ($i == "") $i = "-"; print }')
  [ -n "$MS_ROWS" ] || return 0
  MS_FIRST=$(printf '%s\n' "$MS_ROWS" | awk -F'\t' '
    function key(v,  p) { sub(/^v/, "", v); split(v, p, "."); return p[1] * 1000000 + p[2] * 1000 + p[3] }
    $2 == "open" && (first == "" || key($1) < key(first)) { first = $1 }
    END { print first }')
  MS_THIS=$MS_FIRST
  [ -n "$MS_THIS" ] || MS_THIS=$(printf '%s\n' "$MS_ROWS" | awk -F'\t' '
    function key(v,  p) { sub(/^v/, "", v); split(v, p, "."); return p[1] * 1000000 + p[2] * 1000 + p[3] }
    key($1) > top { top = key($1); last = $1 }
    END { split(substr(last, 2), p, "."); print "v" p[1] "." p[2] + 1 ".0" }')
}

# at_spot <worktree path> <key> <name>: the worktree is the side spot of that name in that repo.
at_spot() { [ "$(real_path "$1")" = "$(real_path "$(spot "$2" "$3")")" ]; }

# side_missing <name> <dirty 0|1>: what the side would lose, summed over the repos: commits not on
# main, stashes of the branch, commits only a detached worktree at its spot holds, commits a worktree left on
# a detached HEAD (reflog orphans) and, with dirty=1, a dirty worktree. Loose stashes are counted per repo
# elsewhere (loose_stashes).
side_missing() {
  local name="$1" dirty="$2" k repo n=0 c st br p id
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    if has_branch "$repo" "$name"; then
      c=$(ahead "$k" "$name")
      n=$((n + ${c:-0}))
    fi
    c=$(git -C "$repo" stash list --format=%gs 2>/dev/null | awk -v a="On $name: " -v b="WIP on $name: " 'index($0, a) == 1 || index($0, b) == 1 { n++ } END { print n + 0 }')
    n=$((n + c))
    while IFS=$'\t' read -r st br p; do
      at_spot "$p" "$k" "$name" || continue
      if [ "$br" = - ]; then
        [ -d "$p" ] || continue
        c=$(git -C "$p" rev-list --count HEAD --not --branches 2>/dev/null)
        n=$((n + ${c:-0}))
      elif id=$(wt_id "$repo" "$p"); then
        c=$(reflog_orphans "$repo" "$id" | wc -l)
        n=$((n + c))
      fi
      if [ "$dirty" -eq 1 ] && [ -d "$p" ] && [ -n "$(git -C "$p" status --porcelain --untracked-files=all 2>/dev/null)" ]; then
        n=$((n + 1))
      fi
    done < <(wt_list "$repo")
  done
  echo "$n"
}

# loose_stashes: '<key>\t<count>' for each repo holding stashes no branch owns ('(no branch)' and autostash).
loose_stashes() {
  local k n
  for k in "${KEYS[@]}"; do
    n=$(git -C "$(repo_dir "$k")" stash list --format=%gs 2>/dev/null | awk '/^(On|WIP on) \(no branch\): / || $0 == "autostash" { n++ } END { print n + 0 }')
    [ "$n" -eq 0 ] || printf '%s\t%s\n' "$k" "$n"
  done
  return 0
}

# side_start <name>: the earliest start date over the repos: the oldest line of the branch
# reflog, else the date of the side marker's commit; '-' without a branch.
side_start() {
  local name="$1" k repo d best="" mark
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    has_branch "$repo" "$name" || continue
    d=$(git -C "$repo" reflog show --date=short --format=%gd "refs/heads/$name" 2>/dev/null | tail -n 1 | sed -n 's/^.*@{\(.*\)}$/\1/p')
    if [ -z "$d" ]; then
      mark=$(git -C "$repo" config --get "branch.$name.trunk")
      [ -z "$mark" ] || d=$(git -C "$repo" show -s --format=%cd --date=short "$mark^{commit}" 2>/dev/null)
    fi
    [ -n "$d" ] || continue
    if [ -z "$best" ] || [ "$d" \< "$best" ]; then best=$d; fi
  done
  echo "${best:--}"
}

# scan_tables: what scan_one reads of every side, read once per scan so that its cost does not grow with the
# plans times main's history (the short view runs at every session start). Newline-ended rows: SCAN_PLANS
# '<name>\t<plan>' (plan_sides), and per repo, each prefixed '<key>\t': SCAN_REFS 'refs/heads/<name>',
# SCAN_MERGES '<name>\t<hash>' (main's first-parent commits titled chore(trunk): merge <name>, newest first, as
# merge_commits), SCAN_STASH '<stash subject>' and SCAN_WTS '<real path>' of each worktree record.
scan_tables() {
  local k repo st br p
  SCAN_PLANS=$(plan_sides)$'\n'
  SCAN_REFS="" SCAN_MERGES="" SCAN_STASH="" SCAN_WTS=""
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    SCAN_REFS=$SCAN_REFS$(git -C "$repo" for-each-ref --format='%(refname)' refs/heads/ | awk -v k="$k" '{ print k "\t" $0 }')$'\n'
    SCAN_MERGES=$SCAN_MERGES$(git -C "$repo" log --first-parent --format='%H %s' refs/heads/main 2>/dev/null \
      | awk -v k="$k" '{ h = $1; sub(/^[^ ]+ /, "") } index($0, "chore(trunk): merge ") == 1 { print k "\t" substr($0, 21) "\t" h }')$'\n'
    SCAN_STASH=$SCAN_STASH$(git -C "$repo" stash list --format=%gs 2>/dev/null | awk -v k="$k" '{ print k "\t" $0 }')$'\n'
    while IFS=$'\t' read -r st br p; do SCAN_WTS=$SCAN_WTS$k$'\t'$(real_path "$p")$'\n'; done < <(wt_list "$repo")
  done
}

scan_has() { case $'\n'$SCAN_REFS in *$'\n'"$1"$'\t'"refs/heads/$2"$'\n'*) return 0 ;; esac; return 1; } # <key> <name>
scan_merged() { case $'\n'$SCAN_MERGES in *$'\n'"$1"$'\t'"$2"$'\t'*) return 0 ;; esac; return 1; } # <key> <name>

scan_merges() { # <key> <name>: the side's merge commits in that repo, from SCAN_MERGES, newest first
  local line
  while IFS= read -r line; do
    case "$line" in "$1"$'\t'"$2"$'\t'*) printf '%s\n' "${line##*$'\t'}" ;; esac
  done <<<"$SCAN_MERGES"
}

# scan_traces <name>: in some repo a stash of the branch, a worktree record at the side spot or anything at
# that path. A closed side without its branch and without these has nothing left out and no flag of a branch,
# so scan_one takes it on the short way.
scan_traces() {
  local name="$1" k sp
  for k in "${KEYS[@]}"; do
    case $'\n'$SCAN_STASH in *$'\n'"$k"$'\t'"On $name: "* | *$'\n'"$k"$'\t'"WIP on $name: "*) return 0 ;; esac
    sp=$(spot "$k" "$name")
    if [ -e "$sp" ] || [ -L "$sp" ]; then return 0; fi
    case $'\n'$SCAN_WTS in *$'\n'"$k"$'\t'"$sp"$'\n'*) return 0 ;; esac
  done
  return 1
}

# shipped_tag <name>: the earliest vX.Y.z (z >= 1) tag, of any repo, that holds a merge commit of the side.
shipped_tag() {
  local name="$1" k repo h
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    while IFS= read -r h; do
      [ -z "$h" ] || git -C "$repo" tag --contains "$h" --list 'v*' 2>/dev/null
    done < <(scan_merges "$k" "$name")
  done | awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { v = substr($0, 2); split(v, p, "."); if (p[3] >= 1) print p[1] * 1000000 + p[2] * 1000 + p[3] "\t" $0 }' \
    | sort -n | head -n 1 | cut -f2
}

# suspects <name>: '<key>\t<short hash> <subject>' for the commits that landed on main's first-parent line
# after the side marker, are no merge commit of trunk.sh, change something outside docs/ CLAUDE.md CONTEXT.md
# and carry 'Ref: <name>' in the body (side work committed on main by a wrong cwd).
suspects() {
  local name="$1" k repo mark start h
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    mark=$(git -C "$repo" config --get "branch.$name.trunk")
    [ -n "$mark" ] || continue
    start=$(git -C "$repo" rev-parse -q --verify "$mark^{commit}") || continue
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      git -C "$repo" log -1 --format=%B "$h" | grep -qxF "Ref: $name" || continue
      case "$(git -C "$repo" log -1 --format=%s "$h")" in "chore(trunk): merge "*) continue ;; esac
      git -C "$repo" diff-tree --no-commit-id --name-only -r --root "$h" | grep -qvE '^(docs/|CLAUDE\.md$|CONTEXT\.md$)' || continue
      printf '%s\t%s %s\n' "$k" "$(git -C "$repo" rev-parse --short=7 "$h")" "$(git -C "$repo" log -1 --format=%s "$h")"
    done < <(git -C "$repo" log --first-parent --fixed-strings --grep="Ref: $name" --format=%H "$start..refs/heads/main" 2>/dev/null)
  done
  return 0
}

# scan_sides: one row per side, 9 tab-separated cells:
#   name class mark milestone plan repos missing flags start
scan_sides() {
  local name k repo
  local -a names=() extras=()
  ms_scan
  scan_tables
  while IFS= read -r name; do [ -z "$name" ] || names+=("$name"); done < <(printf '%s' "$SCAN_PLANS" | cut -f1 | sort -u)
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    while IFS= read -r name; do
      case "$name" in main | trunk-tmp/*) continue ;; esac
      printf '%s\n' ${names[@]+"${names[@]}"} | grep -qxF -- "$name" && continue
      printf '%s\n' ${extras[@]+"${extras[@]}"} | grep -qxF -- "$name" && continue
      extras+=("$name")
    done < <(git -C "$repo" for-each-ref --format='%(refname:lstrip=2)' refs/heads/)
  done
  for name in ${names[@]+"${names[@]}"} ${extras[@]+"${extras[@]}"}; do scan_one "$name"; done
  return 0
}

# scan_one <name>: that side's row, none for a branch without a plan that has nothing left out. It reads the
# tables of scan_tables.
scan_one() {
  local name="$1" plan="" pstate="" life=open k repos="" class mark ms eff merged=0 flags="" missing=0
  local wait hold st br p det=0 tag quick=0
  # The first plan naming the side, as plan_for | head -n 1.
  plan=$'\n'$SCAN_PLANS
  case "$plan" in
    *$'\n'"$name"$'\t'*) plan=${plan#*$'\n'"$name"$'\t'} && plan=${plan%%$'\n'*} ;;
    *) plan="" ;;
  esac
  if [ -z "$plan" ]; then
    life=noplan
  else
    pstate=$(plan_field "$plan" state)
    case "$pstate" in done*) life=done ;; dropped* | superseded*) life=drop ;; esac
  fi
  for k in "${KEYS[@]}"; do
    if scan_has "$k" "$name"; then repos="${repos:+$repos,}$k"; fi
    if scan_merged "$k" "$name"; then merged=1; fi
  done
  # The short way: a closed side with no branch, stash or worktree left anywhere.
  case "$life" in done | drop) [ -n "$repos" ] || scan_traces "$name" || quick=1 ;; esac
  case "$life$quick" in
    done0 | drop0) missing=$(side_missing "$name" 1) ;;
    noplan0) missing=$(side_missing "$name" 0) ;;
  esac
  case "$life" in
    open)
      class=default
      wait=$(plan_field "$plan" wait | head -n 1)
      hold=$(plan_field "$plan" hold | head -n 1)
      if [ -n "$wait" ] || [ -n "$hold" ]; then class=gray; fi
      ;;
    noplan)
      [ "$missing" -gt 0 ] || return 0
      class=orange
      ;;
    *)
      if [ "$missing" -gt 0 ]; then class=orange; elif [ "$life" = done ]; then class=green; else class=dropped; fi
      ;;
  esac
  # The milestone: a version, tbd (counted as this milestone, shown tbd→version) or '-'.
  ms=-
  eff=""
  if [ -n "$plan" ]; then
    eff=$(plan_field "$plan" milestone | head -n 1)
    if [ "$eff" = tbd ]; then
      ms=tbd${MS_THIS:+→$MS_THIS}
      eff=$MS_THIS
    elif [ -n "$eff" ]; then
      ms=$eff
    fi
  fi
  # A milestone later than the earliest open one waits; one missing from the table is the merge's
  # business, not the map's.
  if [ "$class" = default ] && [ -n "$eff" ] && [ -n "$MS_FIRST" ] && printf '%s\n' "$MS_ROWS" | cut -f1 | grep -qxF -- "$eff" \
    && [ "$(ver_key "$eff")" -gt "$(ver_key "$MS_FIRST")" ]; then
    class=gray
    flags=next-milestone
  fi
  case "$class" in
    green) mark=✓ ;;
    gray) mark=⏸ ;;
    dropped) mark=- ;;
    *) if [ "$merged" -eq 1 ]; then mark=◐; else mark=○; fi ;;
  esac
  if [ "$class" = default ] && [ "$merged" -eq 1 ] && [ "$(open_boxes "$plan")" = 0 ]; then
    flags="${flags:+$flags,}merged-open"
  fi
  if [ -f "$STATE_DIR/merge-$name.rec" ]; then
    if [ -n "$(rec_raised "$name")" ]; then flags="${flags:+$flags,}half-merged"; else flags="${flags:+$flags,}aborted-merge"; fi
  fi
  [ "$quick" -eq 1 ] || for k in "${KEYS[@]}"; do
    while IFS=$'\t' read -r st br p; do
      if [ "$br" = - ] && at_spot "$p" "$k" "$name"; then det=1; fi
    done < <(wt_list "$(repo_dir "$k")")
  done
  if [ "$det" -eq 1 ]; then flags="${flags:+$flags,}detached"; fi
  if [ "$class" = default ] || [ "$class" = gray ]; then
    if [ -n "$(suspects "$name")" ]; then flags="${flags:+$flags,}suspect"; fi
  fi
  # A branch of a plan's name that is no side: no marker or worktree at the side spot. With the plan
  # open and the marker set, only the worktree is missing and open finishes it.
  if [ -n "$plan" ] && [ "$det" -eq 0 ] && [ "$quick" -eq 0 ]; then
    for k in "${KEYS[@]}"; do
      case "$(side_state "$k" "$name")" in
        none | side) ;;
        half-made | prunable)
          if [ "$life" = open ]; then flags="${flags:+$flags,}half-made"; else flags="${flags:+$flags,}not-side"; fi
          ;;
        *) flags="${flags:+$flags,}not-side" ;;
      esac
    done
  fi
  if [ "$merged" -eq 1 ]; then
    tag=$(shipped_tag "$name")
    if [ -n "$tag" ]; then flags="${flags:+$flags,}shipped:$tag"; fi
  fi
  # A flag several repos raise is one flag.
  flags=$(printf '%s\n' "$flags" | tr ',' '\n' | awk 'NF && !s[$0]++' | paste -sd, -)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$class" "$mark" "$ms" "${plan:--}" "${repos:--}" "$missing" "${flags:--}" "$(if [ "$quick" -eq 1 ]; then echo -; else side_start "$name"; fi)"
}

# side_detail <name>: per repo holding the branch one line '<key>\t<worktree|->\t<short hash> <subject>' for
# each commit not on main, or '<key>\t<worktree|->\t' when it has none; then 'ledger\t<ID>\t<state cell>'.
side_detail() {
  local name="$1" k repo wt st br p c plan n
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    has_branch "$repo" "$name" || continue
    wt=-
    while IFS=$'\t' read -r st br p; do
      [ "$br" = "refs/heads/$name" ] && wt=$p
    done < <(wt_list "$repo")
    c=$(git -C "$repo" log --format='%h %s' "refs/heads/$name" ^refs/heads/main 2>/dev/null)
    if [ -z "$c" ]; then
      printf '%s\t%s\t\n' "$k" "$wt"
    else
      while IFS= read -r n; do printf '%s\t%s\t%s\n' "$k" "$wt" "$n"; done <<<"$c"
    fi
  done
  plan=$(plan_for "$name" | head -n 1)
  [ -z "$plan" ] || ledger_ids "$plan" | sed 's/^/ledger\t/'
  return 0
}

# ledger_ids <plan>: '<ID>\t<state cell>' for each id of the plan (in the order it first appears) that has a
# row in the ledger. An id the plan only mentions as an example has no row and is dropped.
ledger_ids() {
  local files=() f
  for f in "$ROOT/docs/ledger.md" "$ROOT"/docs/archive/ledger-closed-*.md; do [ -f "$f" ] && files+=("$f"); done
  [ "${#files[@]}" -gt 0 ] || return 0
  awk -F'|' '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    FNR == NR { want[$0] = ++n; ord[n] = $0; next }
    /^\| (DEF|UX|REQ|SEC|DEBT)-[0-9]+ / { id = trim($2); if (id in want && !(id in state)) state[id] = trim($(NF - 1)) }
    END { for (i = 1; i <= n; i++) if (ord[i] in state) print ord[i] "\t" state[ord[i]] }' \
    <(grep -oE '(DEF|UX|REQ|SEC|DEBT)-[0-9]+' "$1" 2>/dev/null | awk '!s[$0]++') "${files[@]}"
}

# stale_facts: the number of lines of the status board's '## Facts' whose 'Checked: YYYY-MM-DD' is more than 30
# days before today (a calendar count in awk: BSD and GNU date differ).
stale_facts() {
  local f="$ROOT/docs/plans/status.md"
  [ -f "$f" ] || { echo 0; return 0; }
  awk -v today="$(trunk_today)" '
    function jd(s,  y, m, d, a) {
      y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
      a = int((14 - m) / 12); y = y + 4800 - a; m = m + 12 * a - 3
      return d + int((153 * m + 2) / 5) + 365 * y + int(y / 4) - int(y / 100) + int(y / 400) - 32045
    }
    /^## / { on = ($0 ~ /^## Facts[ \t\r]*$/); next }
    on && match($0, /Checked: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) {
      if (jd(today) - jd(substr($0, RSTART + RLENGTH - 10, 10)) > 30) n++
    }
    END { print n + 0 }' "$f"
}

# tags_by_day: 'YYYY-MM-DD\t<tags>\t<keys>' for the releases between milestones (vX.Y.z with z >= 1): tags made
# on the same day in any repo make one row, the tags and the repos comma-separated.
tags_by_day() {
  local k
  for k in "${KEYS[@]}"; do
    git -C "$(repo_dir "$k")" for-each-ref --format='%(creatordate:short) %(refname:lstrip=2)' refs/tags/ 2>/dev/null \
      | awk -v k="$k" '$2 ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/ { split(substr($2, 2), p, "."); if (p[3] >= 1) print $1 "\t" $2 "\t" k }'
  done | sort -t "$(printf '\t')" -k1,1 -k2,2 | awk -F'\t' '
    function add(list, v,  n, a, i) { n = split(list, a, ","); for (i = 1; i <= n; i++) if (a[i] == v) return list; return (list == "" ? v : list "," v) }
    { if (!($1 in tags)) order[++n] = $1; tags[$1] = add(tags[$1], $2); keys[$1] = add(keys[$1], $3) }
    END { for (i = 1; i <= n; i++) print order[i] "\t" tags[order[i]] "\t" keys[order[i]] }'
}
