#!/usr/bin/env bash
# Usage: heavy.sh <need-GB> <command> [args...]
# Runs one heavy command (build, typecheck, test, e2e) at a time across all agents,
# and only once enough memory is available. Waiting here holds no heavy memory.
# A need above the machine's total memory could never be met, so it exits 2 before taking the lock.
# Returns the command's exit code. The lock is released on EXIT, INT and TERM. Its pid file, not
# the mkdir, is the claim. A lock is taken over when its owner pid is gone, or when it has had no
# pid for over 10 s, which is what a crash between mkdir and the pid write leaves behind (an empty
# pid file counts as no pid). The reaper dir is released the same way while a run holds it, and one
# left by a crash is cleared by the rules of a lock.
# Signals: bash runs the INT/TERM trap only after the running command exits, so the lock stays
# held while the command runs (Ctrl-C in a terminal reaches the command itself).
# Env: HEAVY_LOCK_DIR (the lock dir itself, not a folder to put it in;
#        default ${TMPDIR:-/tmp}/heavy-<uid>.lock, one per user),
#      HEAVY_POLL_S (poll seconds, default 5),
#      HEAVY_FAKE_AVAIL_GB (test hook: pretend this much memory is free; "none" = probe fails),
#      HEAVY_FAKE_TOTAL_GB (test hook: pretend this much memory in total; "none" = probe fails),
#      GITHUB_ACTIONS (true on a GitHub runner: one job per machine, so the command runs at once),
#      HEAVY_SH_HELD (set by heavy.sh for its command: the pid that holds the lock. A heavy.sh run
#        under it runs its command at once while that pid is alive and still owns the lock, so a
#        nested call does not wait on its own ancestor; the outer need-GB covers the nested one.
#        A wrapped command waits for the heavy.sh it started: if it finishes first, the nested
#        one runs without the lock).
set -u

usage() { echo "usage: heavy.sh <need-GB> <command> [args...]" >&2; exit 2; }
[ "$#" -ge 2 ] || usage
NEED_GB="$1"
shift
if ! [[ "$NEED_GB" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "heavy.sh: need-GB must be a number, got '$NEED_GB'" >&2
  exit 2
fi
[ "${GITHUB_ACTIONS:-}" != true ] || exec "$@"

LOCK="${HEAVY_LOCK_DIR:-${TMPDIR:-/tmp}/heavy-$(id -u).lock}"
LOCK="${LOCK%/}"
POLL="${HEAVY_POLL_S:-5}"
STALE_S=10
if [ ! -d "$(dirname "$LOCK")" ] || [ ! -w "$(dirname "$LOCK")" ]; then
  echo "heavy.sh: lock parent dir does not exist or is not writable: $(dirname "$LOCK")" >&2
  exit 2
fi
# The lock is a dir holding at most a pid file. Anything else at that path is never waited on or removed.
if [ -e "$LOCK" ] && { [ ! -d "$LOCK" ] || [ -n "$(ls -A "$LOCK" | grep -vx pid)" ]; }; then
  echo "heavy.sh: $LOCK is not a heavy.sh lock (HEAVY_LOCK_DIR names the lock itself, not a folder for it)" >&2
  exit 2
fi
held=0

# Takes the dir $1 by creating its pid file with noclobber, which opens it O_EXCL, so one process wins.
# mkdir alone is no mutex: uutils mkdir 0.10 reports success to both of two racing callers. The
# read-back fails a claimer that stalled between creating and writing the file until it was cleared.
claim() {
  local p
  mkdir "$1" 2>/dev/null && (set -C; echo "$$" > "$1/pid") 2>/dev/null &&
    read -r p 2>/dev/null < "$1/pid" && [ "$p" = "$$" ]
}

# Removes the dir $1 only while its pid is this process's.
unclaim() {
  if [ "$(cat "$1/pid" 2>/dev/null)" = "$$" ]; then
    rm -f "$1/pid"; rmdir "$1" 2>/dev/null
  fi
}

release() {
  if [ "$held" -eq 1 ]; then unclaim "$LOCK"; fi
  unclaim "$LOCK.reap"
}
trap release EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Free GB as a decimal number, or nothing when it cannot be read.
# macOS: free+inactive+speculative pages; Linux: MemAvailable.
available_gb() {
  if [ -n "${HEAVY_FAKE_AVAIL_GB:-}" ]; then
    [ "$HEAVY_FAKE_AVAIL_GB" = none ] || echo "$HEAVY_FAKE_AVAIL_GB"
  elif [ -r /proc/meminfo ]; then
    awk '/^MemAvailable:/ { printf "%.2f\n", $2 / 1048576 }' /proc/meminfo
  elif command -v vm_stat >/dev/null 2>&1; then
    vm_stat | awk '
      /page size of/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) size = $i }
      /^Pages free:/ { n += $3 }
      /^Pages inactive:/ { n += $3 }
      /^Pages speculative:/ { n += $3 }
      END { if (size > 0) printf "%.2f\n", n * size / 1073741824 }'
  fi
}

# Total GB of the machine as a decimal number, or nothing when it cannot be read.
total_gb() {
  if [ -n "${HEAVY_FAKE_TOTAL_GB:-}" ]; then
    [ "$HEAVY_FAKE_TOTAL_GB" = none ] || echo "$HEAVY_FAKE_TOTAL_GB"
  elif [ -r /proc/meminfo ]; then
    awk '/^MemTotal:/ { printf "%.2f\n", $2 / 1048576 }' /proc/meminfo
  else
    sysctl -n hw.memsize 2>/dev/null | awk '/^[0-9]+$/ { printf "%.2f\n", $1 / 1073741824 }'
  fi
}

# An unreadable total skips this check; the memory wait below still applies.
total=$(total_gb)
if [[ "$total" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v t="$total" -v n="$NEED_GB" 'BEGIN { exit !(n + 0 > t + 0) }'; then
  echo "heavy.sh: needs ${NEED_GB} GB but this machine has ${total} GB in total; lower need-GB" >&2
  exit 2
fi

# True when the path exists and was last modified more than $2 seconds ago (GNU or BSD stat).
older_than() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null) || return 1
  [ -n "$m" ] && [ $(( $(date +%s) - m )) -gt "$2" ]
}

# kill -0 fails with EPERM for another user's live process; ps -p sees every user's processes.
pid_alive() { kill -0 "$1" 2>/dev/null || ps -p "$1" >/dev/null 2>&1; }

# True when the owner of the dir $1 (the lock or the reaper dir) is gone: its pid is not running,
# or it never wrote a pid and the dir is older than STALE_S.
is_stale() {
  local owner
  owner=$(cat "$1/pid" 2>/dev/null)
  if [ -z "$owner" ]; then
    older_than "$1" "$STALE_S"
    return
  fi
  ! pid_alive "$owner"
}

# Removes the dir $1, judged stale, but not a claim made since: rmdir leaves a claimed dir alone, and
# the pid file goes only while it names a dead pid, or is empty and over STALE_S old (its claimer died
# between creating and writing it). Either kind keeps every claimer out until it is gone.
clear_stale() {
  local p
  p=$(cat "$1/pid" 2>/dev/null)
  if { [ -n "$p" ] && ! pid_alive "$p"; } || { [ -z "$p" ] && [ -f "$1/pid" ] && older_than "$1/pid" "$STALE_S"; }; then
    rm -f "$1/pid"
  fi
  rmdir "$1" 2>/dev/null
}

# Only one process at a time may remove a stale lock, so a late reaper cannot delete a lock
# that someone else just took. A reaper that crashed leaves its dir, cleared by the rules of a
# lock: a live reaper's dir is kept however old, as a reaper that stalled still acts once it resumes.
# The wait names that reaper once: a pid reused by a process that is no reaper holds every run here.
reap_stale() {
  local p
  if ! claim "$LOCK.reap"; then
    if is_stale "$LOCK.reap"; then
      clear_stale "$LOCK.reap"
    elif [ "$reap_announced" -eq 0 ] && p=$(cat "$LOCK.reap/pid" 2>/dev/null) && [ -n "$p" ]; then
      echo "heavy.sh: waiting for pid $p to clear a stale lock ($LOCK.reap)" >&2
      reap_announced=1
    fi
    return 0
  fi
  is_stale "$LOCK" && clear_stale "$LOCK"
  unclaim "$LOCK.reap"
}

# Nested under a heavy.sh that still holds this lock: waiting would wait on our own ancestor.
if [ -n "${HEAVY_SH_HELD:-}" ] && [ "$(cat "$LOCK/pid" 2>/dev/null)" = "$HEAVY_SH_HELD" ] && pid_alive "$HEAVY_SH_HELD"; then
  exec "$@"
fi

# A lock gone since the claim failed was just released and the next poll takes it: no wait message.
# Gone at the next poll too, the claim itself fails (a full disk, a parent dir removed or made
# read-only), which the run says once.
announced=0 reap_announced=0 missing=0
until claim "$LOCK"; do
  if [ ! -d "$LOCK" ]; then
    missing=$((missing + 1))
    [ "$missing" -ne 2 ] || echo "heavy.sh: cannot create the lock $LOCK (disk full, or its parent dir gone or read-only?); still trying" >&2
  else
    missing=0
    if is_stale "$LOCK"; then
      reap_stale
    elif [ "$announced" -eq 0 ]; then
      # A pid file is empty for the moment between its claim and its write.
      holder=$(cat "$LOCK/pid" 2>/dev/null) || holder=''
      echo "heavy.sh: waiting for lock held by pid ${holder:-?} ($LOCK)" >&2
      announced=1
    fi
  fi
  sleep "$POLL"
done
held=1
export HEAVY_SH_HELD=$$

waited=0
while :; do
  avail=$(available_gb)
  if ! [[ "$avail" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "heavy.sh: cannot read available memory; running without the memory wait" >&2
    break
  fi
  awk -v a="$avail" -v n="$NEED_GB" 'BEGIN { exit !(a + 0 >= n + 0) }' && break
  if [ "$waited" -eq 0 ]; then
    echo "heavy.sh: waiting for ${NEED_GB} GB free memory (now ${avail} GB)" >&2
    waited=1
  fi
  sleep "$POLL"
done

"$@"
