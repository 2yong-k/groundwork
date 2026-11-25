#!/usr/bin/env bash
# Usage: sync-tokens.sh <source tokens.json> <dest repo>
#        sync-tokens.sh --check <source tokens.json> <dest repo>
# Sync: copies the source to <dest>/design/tokens.json and writes the copy's sha256 to
#       <dest>/design/tokens.source-sha256 (only after the copy succeeded).
# Check: SKIP (exit 0) when the source is absent (CI of another repo); "FAIL tokens drifted"
#        (exit 1) when the source or the copy no longer matches the recorded hash.
# Exit 2 on usage errors, a missing source or a failed copy during sync.
set -u

usage() { echo "usage: sync-tokens.sh [--check] <source tokens.json> <dest repo>" >&2; exit 2; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

check=0
if [ "${1:-}" = "--check" ]; then check=1; shift; fi
[ "$#" -eq 2 ] || usage
source_file="$1"; dest="$2"
copy="$dest/design/tokens.json"
sidecar="$dest/design/tokens.source-sha256"

if [ "$check" -eq 1 ]; then
  if [ ! -f "$source_file" ]; then
    echo "SKIP: source not found ($source_file)"
    exit 0
  fi
  if [ ! -f "$copy" ] || [ ! -f "$sidecar" ]; then
    echo "FAIL tokens drifted: $dest has no synced design/tokens.json; run sync-tokens.sh"
    exit 1
  fi
  recorded=$(tr -d '[:space:]' < "$sidecar")
  if [ "$(sha256_of "$source_file")" != "$recorded" ] || [ "$(sha256_of "$copy")" != "$recorded" ]; then
    echo "FAIL tokens drifted: run sync-tokens.sh $source_file $dest"
    exit 1
  fi
  echo "tokens in sync"
  exit 0
fi

if [ ! -f "$source_file" ]; then
  echo "sync-tokens: source not found: $source_file" >&2
  exit 2
fi
mkdir -p "$dest/design" || exit 2
cp "$source_file" "$copy" || exit 2
hash=$(sha256_of "$copy") && [ -n "$hash" ] || { echo "sync-tokens: cannot hash $copy" >&2; exit 2; }
printf '%s\n' "$hash" > "$sidecar" || exit 2
echo "synced $source_file -> $copy"
