#!/usr/bin/env bash
#
# Writes the YTD new+updated Formula/Cask count (homebrew-core + cask) to a
# JSON file that Smiirl's Custom Counter polls directly (JSON URL mode). See
# README.md for how this works and what the env vars below do.

set -euo pipefail

SINCE_DATE="${SINCE_DATE:-$(date -u +%Y-01-01)}"
CACHE_DIR="${CACHE_DIR:-.cache}"
OUTPUT_FILE="${OUTPUT_FILE:-docs/counter.json}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$CACHE_DIR/last_value"

mkdir -p "$CACHE_DIR" "$(dirname "$OUTPUT_FILE")"

set_output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >>"$GITHUB_OUTPUT"
  fi
}

feed_marker() {
  local url="$1"
  curl --fail --silent "$url" | grep -o '<updated>[^<]*</updated>' | head -1
}

sync_repo() {
  local url="$1" dir="$2"
  if [ -d "$dir" ]; then
    echo "Updating cached clone at $dir..." >&2
    git -C "$dir" fetch origin +refs/heads/main:refs/heads/main >&2
  else
    echo "No cached clone at $dir; doing a one-time full clone..." >&2
    git clone --bare --single-branch --branch main "$url" "$dir" >&2
  fi
}

core_marker="$(feed_marker https://github.com/Homebrew/homebrew-core/commits/main.atom)"
cask_marker="$(feed_marker https://github.com/Homebrew/homebrew-cask/commits/main.atom)"
core_marker_file="$CACHE_DIR/core_marker"
cask_marker_file="$CACHE_DIR/cask_marker"

if [ -f "$core_marker_file" ] && [ -f "$cask_marker_file" ] \
  && [ "$core_marker" = "$(cat "$core_marker_file")" ] \
  && [ "$cask_marker" = "$(cat "$cask_marker_file")" ]; then
  echo "no new commits on either tap since last check, skipping"
  set_output changed false
  exit 0
fi

sync_repo https://github.com/Homebrew/homebrew-core.git "$CACHE_DIR/core.git"
core_count="$(python3 "$SCRIPT_DIR/scripts/count_pace.py" --repo-dir "$CACHE_DIR/core.git" --path-regex '^Formula/.*\.rb$' --since "$SINCE_DATE")"

sync_repo https://github.com/Homebrew/homebrew-cask.git "$CACHE_DIR/cask.git"
cask_count="$(python3 "$SCRIPT_DIR/scripts/count_pace.py" --repo-dir "$CACHE_DIR/cask.git" --path-regex '^Casks/.*\.rb$' --since "$SINCE_DATE")"

count=$((core_count + cask_count))
echo "core: $core_count, cask: $cask_count, combined: $count"

echo "$core_marker" >"$core_marker_file"
echo "$cask_marker" >"$cask_marker_file"

old_count=""
if [ -f "$STATE_FILE" ]; then
  old_count="$(cat "$STATE_FILE")"
fi

if [ "$count" = "$old_count" ]; then
  echo "count unchanged at $count, not rewriting $OUTPUT_FILE"
  set_output changed false
  exit 0
fi

printf '{"number":%s}' "$count" >"$OUTPUT_FILE"
echo "$count" >"$STATE_FILE"
echo "wrote $count to $OUTPUT_FILE"

if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  git -C "$SCRIPT_DIR" config user.name "github-actions[bot]"
  git -C "$SCRIPT_DIR" config user.email "github-actions[bot]@users.noreply.github.com"
  git -C "$SCRIPT_DIR" add "$OUTPUT_FILE"
  if git -C "$SCRIPT_DIR" diff --cached --quiet; then
    echo "$OUTPUT_FILE unchanged in git, nothing to commit"
  else
    git -C "$SCRIPT_DIR" commit -m "counter: $count"
    git -C "$SCRIPT_DIR" push
  fi
else
  echo "not running in GitHub Actions, skipping git commit/push"
fi

set_output changed true
