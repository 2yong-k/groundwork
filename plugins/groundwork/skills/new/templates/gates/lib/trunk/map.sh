# The trunk map of trunk.sh, sourced by it: the short view (no argument), status, and the HTML page (map).
# Everything comes from git, the status board's milestone table and the plan heads; no AI is involved.

SHORT_CAP=10 # open sides the short view lists; the rest is '<N> more'
SHORT_EACH_CAP=3 # suspect lines and kept closed sides the short view lists one per line; the rest is '<N> more'

flag_text() { # <flag>: the words of a scan_sides flag
  case "$1" in
    merged-open) echo "merged but not closed" ;;
    half-merged) echo "half merged" ;;
    aborted-merge) echo "aborted merge" ;;
    detached) echo "detached" ;;
    suspect) echo "suspect" ;;
    not-side) echo "not a side branch" ;;
    half-made) echo "rerun open to resume" ;;
    next-milestone) echo "waits for the next milestone" ;;
    shipped:*) echo "already in prod via ${1#shipped:}" ;;
    *) echo "$1" ;;
  esac
}

mmdd() { case "$1" in ????-??-??) echo "${1#*-}" ;; *) echo "$1" ;; esac; } # YYYY-MM-DD -> MM-DD

# side_ver <milestone cell>: the version the cell stands for ('tbd→v0.2.0' is v0.2.0), or empty.
side_ver() { case "$1" in tbd→*) echo "${1#tbd→}" ;; tbd | -) echo "" ;; *) echo "$1" ;; esac; }

# side_history <class> <repos> <milestone cell>: a finished side whose branch is gone and whose milestone is reached:
# what that milestone shipped. The short view leaves it out; status and the page list it under its milestone
# (opening a milestone shows all its sides). A finished side of Milestone: tbd counts as this milestone, which is
# never a reached one, so it stays in this milestone's bundle.
side_history() {
  local v
  [ "$1" = green ] && [ "$2" = - ] || return 1
  v=$(side_ver "$3")
  [ -n "$v" ] || return 1
  printf '%s\n' "$MS_ROWS" | awk -F'\t' -v v="$v" '$1 == v && $2 == "reached" { f = 1 } END { exit !f }'
}

# side_shown <class> <repos> <milestone cell>: whether the short view lists the side. A side dropped with nothing
# left out is only counted, everywhere; a side in history is only in status and on the page.
side_shown() {
  [ "$1" != dropped ] || return 1
  ! side_history "$@"
}

# side_status <name> <plan>: the reason of the plan's Waiting: or On hold:, else the title of the side's newest commit
# that main lacks; '-' when there is neither.
side_status() {
  local name="$1" plan="$2" s="" k best="" line t
  if [ "$plan" != - ]; then
    s=$(plan_field "$plan" wait | head -n 1)
    [ -n "$s" ] || s=$(plan_field "$plan" hold | head -n 1)
  fi
  if [ -z "$s" ]; then
    for k in "${KEYS[@]}"; do
      has_branch "$(repo_dir "$k")" "$name" || continue
      line=$(git -C "$(repo_dir "$k")" log -1 --format='%ct %s' "refs/heads/$name" ^refs/heads/main 2>/dev/null)
      [ -n "$line" ] || continue
      t=${line%% *}
      if [ -z "$best" ] || [ "$t" -gt "${best%% *}" ]; then best=$line; fi
    done
    s=${best#* }
  fi
  echo "${s:--}"
}

side_ahead() { # <name> <repos cell>: commits main lacks, summed over the side's repos
  local n=0 k c
  [ "$2" != - ] || { echo 0; return 0; }
  for k in $(printf '%s' "$2" | tr ',' ' '); do
    c=$(ahead "$k" "$1")
    n=$((n + ${c:-0}))
  done
  echo "$n"
}

# map_load: SIDES (the scan_sides rows) and the milestone variables of ms_scan, which scan_sides sets in a
# subshell and so has to be run here as well.
map_load() {
  ms_scan
  SIDES=$(scan_sides)
}

sides_each() { # run "$@" name class mark ms plan repos missing flags start for each row of SIDES
  local name class mark ms plan repos missing flags start
  while IFS=$'\t' read -r name class mark ms plan repos missing flags start; do
    [ -n "$name" ] || continue
    "$@" "$name" "$class" "$mark" "$ms" "$plan" "$repos" "$missing" "$flags" "$start"
  done <<<"$SIDES"
}

short_first() { echo "trunk.sh short map · $ROOT"; }

# short_mains: each repo's main tip and the uncommitted changes of its main checkout, which a session reads at its
# start instead of a handoff line; the checkout's HEAD too when it is not on main.
short_mains() {
  local k repo tip n head pre
  for k in "${KEYS[@]}"; do
    repo=$(repo_dir "$k")
    pre=""
    [ "$k" = . ] || pre="$k: "
    tip=$(git -C "$repo" rev-parse -q --verify refs/heads/main) || tip="(none)"
    n=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    head=$(git -C "$repo" symbolic-ref -q HEAD || echo detached)
    if [ "$head" = refs/heads/main ]; then
      echo "${pre}main ${tip:0:12} · uncommitted changes $n"
    else
      echo "${pre}main ${tip:0:12} · uncommitted changes $n · checkout HEAD ${head#refs/heads/}"
    fi
  done
}

short_milestones() {
  local reached this name qa
  case "$MS_OK" in
    0) echo "Milestone: no status board (docs/plans/status.md) · now $(mmdd "$(trunk_today)")"; return 0 ;;
    2) echo "Milestone: cannot read the milestone table ('## Milestones' of docs/plans/status.md) · now $(mmdd "$(trunk_today)")"; return 0 ;;
  esac
  reached=$(printf '%s\n' "$MS_ROWS" | awk -F'\t' '
    function key(v,  p) { sub(/^v/, "", v); split(v, p, "."); return p[1] * 1000000 + p[2] * 1000 + p[3] }
    $2 == "reached" && key($1) > top { top = key($1); r = $1 "\t" $3 }
    END { print r }')
  if [ -n "$reached" ]; then reached="reached ${reached%%$'\t'*} $(mmdd "${reached#*$'\t'}")"; else reached="no milestone reached"; fi
  if [ -z "$MS_THIS" ]; then
    echo "Milestone: $reached · no milestone in the table · now $(mmdd "$(trunk_today)")"
    return 0
  fi
  this=$(printf '%s\n' "$MS_ROWS" | awk -F'\t' -v v="$MS_THIS" '$1 == v { print $4 "\t" $5 }')
  if [ -n "$this" ]; then
    name=${this%%$'\t'*}
    qa=${this#*$'\t'}
    echo "Milestone: $reached → this $MS_THIS \"$name\" · QA $qa · now $(mmdd "$(trunk_today)")"
  else
    echo "Milestone: $reached → this $MS_THIS (not in the table yet) · now $(mmdd "$(trunk_today)")"
  fi
}

short_releases() { # releases since the last milestone reached, newest three
  local since rel n
  since=$(printf '%s\n' "$MS_ROWS" | awk -F'\t' '$2 == "reached" && $3 > d { d = $3 } END { print d }')
  rel=$(tags_by_day | awk -F'\t' -v s="$since" '$1 >= s')
  [ -n "$rel" ] || return 0
  n=$(printf '%s\n' "$rel" | wc -l | tr -d ' ')
  [ "$n" -le 3 ] || echo "Releases in between, $((n - 3)) more"
  printf '%s\n' "$rel" | tail -n 3 | while IFS=$'\t' read -r d tags keys; do
    echo "Release in between: $(mmdd "$d") ${tags//,/ · }$([ "$keys" = . ] || echo " ($keys)")"
  done
}

short_bundle_row() { # one SIDES row: collects the sides of this milestone
  local name="$1" class="$2" mark="$3" ms="$4" repos="$6"
  side_shown "$class" "$repos" "$ms" || return 0
  [ "$(side_ver "$ms")" = "$MS_THIS" ] || return 0
  BUNDLE="${BUNDLE:+$BUNDLE · }$mark $name"
  BUNDLE_N=$((BUNDLE_N + 1))
  [ "$BUNDLE_N" -gt "$SHORT_CAP" ] || BUNDLE_SHOWN=$BUNDLE
}

short_bundle() {
  BUNDLE="" BUNDLE_N=0 BUNDLE_SHOWN=""
  [ -n "$MS_THIS" ] || return 0
  sides_each short_bundle_row
  [ "$BUNDLE_N" -gt 0 ] || { echo "$MS_THIS bundle: no side branch"; return 0; }
  if [ "$BUNDLE_N" -gt "$SHORT_CAP" ]; then
    echo "$MS_THIS bundle: $BUNDLE_SHOWN · $((BUNDLE_N - SHORT_CAP)) more"
  else
    echo "$MS_THIS bundle: $BUNDLE"
  fi
}

short_open_row() {
  local name="$1" class="$2" mark="$3" plan="$5" repos="$6" start="$9" st
  case "$class" in default | gray) ;; *) return 0 ;; esac
  OPEN_N=$((OPEN_N + 1))
  if [ "$OPEN_N" -gt "$SHORT_CAP" ]; then
    OPEN_REST="${OPEN_REST:+$OPEN_REST, }$name"
    return 0
  fi
  echo "  $mark $name · repos $repos · $(side_ahead "$name" "$repos") commit(s) ahead · start $(mmdd "$start")"
  st=$(side_status "$name" "$plan")
  [ "$st" = - ] || echo "      $st"
}

short_open() {
  OPEN_N=0 OPEN_REST=""
  local total
  total=$(printf '%s\n' "$SIDES" | awk -F'\t' '$2 == "default" || $2 == "gray" { n++ } END { print n + 0 }')
  if [ "$total" -eq 0 ]; then echo "Open side branches: none"; return 0; fi
  echo "Open side branches $total"
  sides_each short_open_row
  [ "$OPEN_N" -le "$SHORT_CAP" ] || echo "  $((OPEN_N - SHORT_CAP)) more: $OPEN_REST"
}

short_missing() {
  local rows total parts loose
  rows=$(printf '%s\n' "$SIDES" | awk -F'\t' '$7 > 0 { print $1 " " $7 }')
  loose=$(loose_stashes | awk -F'\t' '{ printf "%s%s %s", (n++ ? " · " : ""), $1, $2 }')
  [ -n "$rows$loose" ] || return 0
  if [ -n "$rows" ]; then
    total=$(printf '%s\n' "$rows" | awk '{ n += $2 } END { print n }')
    parts=$(printf '%s\n' "$rows" | awk -v cap="$SHORT_CAP" 'NR <= cap { printf "%s%s", (NR > 1 ? " · " : ""), $0 } END { if (NR > cap) printf " · %d more", NR - cap }')
    echo "Left out $total: $parts"
  fi
  [ -z "$loose" ] || echo "Left out: branchless stashes (per repo) $loose"
}

# flag_names <flag> <this-milestone-only 0|1>: the sides that carry the flag (shipped matches any shipped:<tag>).
flag_names() { # <flag> <this-milestone-only 0|1>
  printf '%s\n' "$SIDES" | awk -F'\t' -v f="$1" -v only="$2" -v this="$MS_THIS" '
    function has(list,  n, a, i) { n = split(list, a, ","); for (i = 1; i <= n; i++) if (a[i] == f || (f == "shipped" && index(a[i], "shipped:") == 1)) return 1; return 0 }
    NF && has($8) { v = $4; sub(/^tbd→/, "", v); if (only && v != this) next; print $1 }'
}

short_flags() {
  local f names tags t n
  for f in merged-open half-merged aborted-merge detached not-side half-made next-milestone; do
    names=$(flag_names "$f" 0 | paste -sd, - | sed 's/,/, /g')
    [ -z "$names" ] || echo "$(flag_text "$f"): $names"
  done
  # A suspect commit is quoted: the side may be open for days and the commit is the evidence.
  names=$(flag_names suspect 0)
  for n in $(printf '%s\n' "$names" | head -n "$SHORT_EACH_CAP"); do
    echo "Suspect: $n — side branch work landed on main? $(suspects "$n" | head -n 1 | awk -F'\t' '{ print ($1 == "." ? "" : $1 " ") $2 }')"
  done
  n=$(printf '%s\n' "$names" | awk 'NF { c++ } END { print c + 0 }')
  [ "$n" -le "$SHORT_EACH_CAP" ] || echo "Suspect, $((n - SHORT_EACH_CAP)) more: $(printf '%s\n' "$names" | tail -n +"$((SHORT_EACH_CAP + 1))" | paste -sd, - | sed 's/,/, /g')"
  tags=$(printf '%s\n' "$SIDES" | awk -F'\t' '{ n = split($8, a, ","); for (i = 1; i <= n; i++) if (index(a[i], "shipped:") == 1) print substr(a[i], 9) }' | sort -u)
  for t in $tags; do
    names=$(printf '%s\n' "$SIDES" | awk -F'\t' -v t="shipped:$t" -v this="$MS_THIS" '{ v = $4; sub(/^tbd→/, "", v); if (v != this) next; n = split($8, a, ","); for (i = 1; i <= n; i++) if (a[i] == t) print $1 }' | paste -sd, - | sed 's/,/, /g')
    [ -z "$names" ] || echo "$(flag_text "shipped:$t"): $names"
  done
  return 0
}

# tidy_rows: for each side whose plan is closed and that still has a branch, 'ok|no\t<name>\t<reasons>' ('-'
# when there are none): ok means tidy removes it.
tidy_rows() {
  local name class mark ms plan repos missing flags start lines
  while IFS=$'\t' read -r name class mark ms plan repos missing flags start; do
    [ -n "$name" ] && [ "$plan" != - ] && [ "$repos" != - ] || continue
    plan_closed "$plan" || continue
    lines=$(tidy_blockers "$name")
    if [ -z "$lines" ]; then
      printf 'ok\t%s\t-\n' "$name"
    else
      printf 'no\t%s\t%s\n' "$name" "$(printf '%s\n' "$lines" | sed 's/^\.: //' | paste -sd, - | sed 's/,/; /g')"
    fi
  done <<<"$SIDES"
}

short_tidy() {
  local rows ok
  rows=$(tidy_rows)
  [ -n "$rows" ] || return 0
  ok=$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "ok" { printf "%s%s", (n++ ? ", " : ""), $2 }')
  echo "To tidy:${ok:+ can remove $ok}"
  printf '%s\n' "$rows" | awk -F'\t' -v cap="$SHORT_EACH_CAP" '
    $1 != "no" { next }
    ++k <= cap { r = $3; n = split(r, a, "; "); print "  " $2 " — kept: " a[1] (n > 1 ? " (" n - 1 " more)" : ""); next }
    { rest = rest (rest == "" ? "" : ", ") $2 }
    END { if (k > cap) print "  kept, " k - cap " more: " rest }'
}

short_footer() {
  local dropped
  dropped=$(printf '%s\n' "$SIDES" | awk -F'\t' '$2 == "dropped" { n++ } END { print n + 0 }')
  echo "Stale facts $(stale_facts) · dropped · superseded $dropped"
}

cmd_short() {
  short_first
  short_mains
  map_load
  short_milestones
  short_releases
  short_bundle
  short_open
  short_missing
  short_flags
  short_tidy
  short_footer
}

cmd_status() {
  echo "trunk.sh status · $ROOT"
  map_load
  STATUS_REACHED=""
  sides_each status_side
  status_reached
  status_loose
  short_footer
}

# status_reached: under each reached milestone, in table order, the sides it shipped (side_history).
status_reached() {
  local v st d rest lines
  while IFS=$'\t' read -r v st d rest; do
    [ "$st" = reached ] || continue
    STATUS_REACHED=$v
    lines=$(sides_each status_side)
    [ -z "$lines" ] || printf 'Reached milestone %s (%s)\n%s\n' "$v" "$(mmdd "$d")" "$lines"
  done <<<"$MS_ROWS"
  STATUS_REACHED=""
}

status_loose() {
  local loose
  loose=$(loose_stashes | awk -F'\t' '{ printf "%s%s %s", (n++ ? " · " : ""), $1, $2 }')
  [ -z "$loose" ] || echo "Left out: branchless stashes (per repo) $loose"
}

# status_side <SIDES row>: the side's lines. With STATUS_REACHED empty only the sides outside history, else only
# those in the history of that milestone.
status_side() {
  local name="$1" class="$2" mark="$3" ms="$4" plan="$5" repos="$6" missing="$7" flags="$8" start="$9"
  local f txt k wt c
  [ "$class" != dropped ] || return 0
  if side_history "$class" "$repos" "$ms"; then
    [ "$(side_ver "$ms")" = "${STATUS_REACHED:-}" ] || return 0
  else
    [ -z "${STATUS_REACHED:-}" ] || return 0
  fi
  txt=""
  for f in $(printf '%s' "$flags" | tr ',' ' '); do
    [ "$f" = - ] || txt="${txt:+$txt, }$(flag_text "$f")"
  done
  echo "$mark $name · $class · milestone $ms · repos $repos · left out $missing · start $(mmdd "$start")${txt:+ · $txt}"
  [ "$plan" = - ] || echo "    plan $plan"
  while IFS=$'\t' read -r k wt c; do
    [ -n "$k" ] || continue
    case "$k" in
      ledger) echo "    $wt ${c:-}" ;;
      *)
        if [ -n "$c" ]; then echo "    $k · $wt · $c"; else echo "    $k · $wt"; fi
        ;;
    esac
  done < <(side_detail "$name")
}

# json_str <text>: the text as the inside of a JSON string: backslash, quote and control characters escaped, and
# '<' as \u003c, so a data block can never hold '</script>'. Bytes of 0x80 and up (Korean) pass unchanged.
json_str() {
  local s="$1" i ch esc
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//</\\u003c}
  s=${s//$'\n'/\\n}
  s=${s//$'\t'/\\t}
  s=${s//$'\r'/\\r}
  case "$s" in
    *[$'\001'-$'\037']*)
      for i in 1 2 3 4 5 6 7 8 11 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31; do
        printf -v ch "\\$(printf '%03o' "$i")"
        printf -v esc '\\u%04x' "$i"
        s=${s//"$ch"/$esc}
      done
      ;;
  esac
  printf '%s' "$s"
}

js() { printf '"%s"' "$(json_str "$1")"; } # a JSON string value
js_or_empty() { if [ "$1" = - ]; then js ""; else js "$1"; fi; } # a '-' cell is an empty value
js_list() { # <comma list>: a JSON array of strings; '-' and empty give []
  local item out=""
  [ "$1" != - ] || { printf '[]'; return 0; }
  for item in $(printf '%s' "$1" | tr ',' ' '); do out="${out:+$out,}$(js "$item")"; done
  printf '[%s]' "$out"
}

json_milestones() {
  local v st d n qa out=""
  while IFS=$'\t' read -r v st d n qa; do
    [ -n "$v" ] || continue
    out="${out:+$out,}{\"version\":$(js "$v"),\"name\":$(js_or_empty "$n"),\"state\":$(js "$st"),\"date\":$(js_or_empty "$d"),\"qa\":$(js_or_empty "$qa")}"
  done <<<"$MS_ROWS"
  printf '%s' "$out"
}

json_releases() {
  local d tags keys out=""
  while IFS=$'\t' read -r d tags keys; do
    [ -n "$d" ] || continue
    out="${out:+$out,}{\"date\":$(js "$d"),\"tag\":$(js "${tags//,/, }"),\"repos\":$(js_list "$keys")}"
  done < <(tags_by_day)
  printf '%s' "$out"
}

json_detail() { # <name>: the detail object of a side
  local k wt c repos="" ledger="" cur="" curwt="" commits=""
  while IFS=$'\t' read -r k wt c; do
    [ -n "$k" ] || continue
    if [ "$k" = ledger ]; then
      ledger="${ledger:+$ledger,}{\"id\":$(js "$wt"),\"state\":$(js "$c")}"
      continue
    fi
    if [ "$k" != "$cur" ]; then
      [ -z "$cur" ] || repos="${repos:+$repos,}{\"key\":$(js "$cur"),\"worktree\":$(js "$curwt"),\"commits\":[$commits]}"
      cur=$k curwt=$wt commits=""
    fi
    [ -z "$c" ] || commits="${commits:+$commits,}$(js "$c")"
  done < <(side_detail "$1")
  [ -z "$cur" ] || repos="${repos:+$repos,}{\"key\":$(js "$cur"),\"worktree\":$(js "$curwt"),\"commits\":[$commits]}"
  printf '{"repos":[%s],"ledger":[%s]}' "$repos" "$ledger"
}

# json_sides: every side but the dropped ones; history (side_history) marks those the page lists under their
# reached milestone instead of drawing them.
json_sides() {
  local name class mark ms plan repos missing flags start rel out="" row hist
  while IFS=$'\t' read -r name class mark ms plan repos missing flags start; do
    [ -n "$name" ] && [ "$class" != dropped ] || continue
    hist=false
    if side_history "$class" "$repos" "$ms"; then hist=true; fi
    rel=$plan
    case "$plan" in "$ROOT"/*) rel=${plan#"$ROOT"/} ;; esac
    row="{\"name\":$(js "$name"),\"class\":$(js "$class"),\"mark\":$(js "$mark"),\"milestone\":$(js "$ms"),\"repos\":$(js_list "$repos"),"
    row="$row\"start\":$(js "$start"),\"status\":$(js "$(side_status "$name" "$plan")"),\"missing\":$missing,\"flags\":$(js_list "$flags"),"
    row="$row\"plan\":$(js "$rel"),\"history\":$hist,\"detail\":$(json_detail "$name")}"
    out="${out:+$out,}$row"
  done <<<"$SIDES"
  printf '%s' "$out"
}

json_tidy() {
  local ok name why out=""
  while IFS=$'\t' read -r ok name why; do
    [ -n "$name" ] || continue
    if [ "$ok" = ok ]; then
      out="${out:+$out,}{\"name\":$(js "$name"),\"ok\":true,\"why\":\"\"}"
    else
      out="${out:+$out,}{\"name\":$(js "$name"),\"ok\":false,\"why\":$(js "$why")}"
    fi
  done < <(tidy_rows)
  printf '%s' "$out"
}

json_suspects() {
  local name flags k c out=""
  while IFS=$'\t' read -r name flags; do
    case ",$flags," in *,suspect,*) ;; *) continue ;; esac
    while IFS=$'\t' read -r k c; do
      [ -n "$k" ] || continue
      out="${out:+$out,}{\"name\":$(js "$name"),\"key\":$(js "$k"),\"commit\":$(js "$c")}"
    done < <(suspects "$name")
  done < <(printf '%s\n' "$SIDES" | cut -f1,8)
  printf '%s' "$out"
}

json_loose() {
  local k n out=""
  while IFS=$'\t' read -r k n; do
    [ -n "$k" ] || continue
    out="${out:+$out,}{\"key\":$(js "$k"),\"count\":$n}"
  done < <(loose_stashes)
  printf '%s' "$out"
}

# map_json: the data of the page; one line, no raw '<'.
map_json() {
  local dropped
  dropped=$(printf '%s\n' "$SIDES" | awk -F'\t' '$2 == "dropped" { n++ } END { print n + 0 }')
  printf '{"root":%s,"today":%s,"milestones":[%s],"releases":[%s],"sides":[%s],"dropped":%s,"tidy":[%s],"stale":%s,"suspects":[%s],"loose":[%s]}' \
    "$(js "$ROOT")" "$(js "$(trunk_today)")" "$(json_milestones)" "$(json_releases)" "$(json_sides)" "$dropped" \
    "$(json_tidy)" "$(stale_facts)" "$(json_suspects)" "$(json_loose)"
}

MAP_FILE_REL=.superpowers/trunk-map.html

# map_write [--loaded]: scans and writes the page; prints nothing. With --loaded it takes the scan map_load just
# made in this shell. The data replaces the one line /*TRUNK_DATA*/ of map.html.
map_write() {
  local tmpl="$SCRIPT_DIR/lib/trunk/map.html" out="$ROOT/$MAP_FILE_REL" data
  if [ ! -f "$tmpl" ]; then
    echo "no map.html — copy it along into lib/trunk/ next to trunk.sh"
    return 1
  fi
  mkdir -p "$ROOT/.superpowers" || return 1
  [ "${1:-}" = --loaded ] || map_load
  data="$out.data.$$"
  map_json >"$data"
  awk 'FNR == NR { d = $0; next } $0 == "/*TRUNK_DATA*/" { print d; next } { print }' "$data" "$tmpl" >"$out.new.$$" \
    && mv "$out.new.$$" "$out"
  local rc=$?
  rm -f "$data" "$out.new.$$"
  return "$rc"
}

weft_bin() { # the weft CLI: on PATH, else the app's own folder
  if command -v weft >/dev/null 2>&1; then
    command -v weft
  elif [ -x "$HOME/.weft/bin/weft" ]; then
    echo "$HOME/.weft/bin/weft"
  fi
}

# map_url: the file URL of the page, every byte outside [A-Za-z0-9/._~-] percent-encoded (upper-case hex), the
# form Weft keeps for a path with spaces or Korean in it.
map_url() {
  local LC_ALL=C p="$ROOT/$MAP_FILE_REL" out="" c n i
  for ((i = 0; i < ${#p}; i++)); do
    c=${p:i:1}
    case "$c" in
      [A-Za-z0-9/._~-]) out="$out$c" ;;
      *)
        printf -v n '%d' "'$c"
        printf -v c '%%%02X' $((n & 255))
        out="$out$c"
        ;;
    esac
  done
  printf 'file://%s\n' "$out"
}

# map_show <1|0>: reloads the Weft window that shows the page; with 1 it opens one when none does.
map_show() {
  local weft url raw list
  weft=$(weft_bin)
  [ -n "$weft" ] || return 0
  url=$(map_url)
  raw="file://$ROOT/$MAP_FILE_REL"
  list=$("$weft" browser list 2>/dev/null)
  if printf '%s\n' "$list" | grep -qF -e "$url"; then
    "$weft" browser reload "$url" >/dev/null 2>&1
  elif printf '%s\n' "$list" | grep -qF -e "$raw"; then
    "$weft" browser reload "$raw" >/dev/null 2>&1
  elif [ "$1" -eq 1 ]; then
    "$weft" browser open "$url" >/dev/null 2>&1
  fi
  return 0
}

cmd_map() {
  echo "trunk.sh map · $ROOT"
  if ! map_write; then
    echo "Stop: could not write the map HTML — $ROOT/$MAP_FILE_REL"
    exit 1
  fi
  echo "$ROOT/$MAP_FILE_REL"
  if [ -z "$(weft_bin)" ]; then
    echo "no Weft CLI — open the path above in a browser"
    return 0
  fi
  map_show 1
}

# map_refresh_if_open [--loaded]: after a merge, rewrites the page (from the scan map_load just made, with
# --loaded) and reloads it only if a Weft window shows it.
map_refresh_if_open() {
  map_write "$@" >/dev/null 2>&1 || return 0
  map_show 0
}
