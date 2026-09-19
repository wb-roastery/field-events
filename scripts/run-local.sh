#!/usr/bin/env bash
#
# Wrapper for running update-smiirl-counter.sh locally on a schedule (e.g.
# cron every minute) instead of via GitHub Actions. See README.md.
#
# Guards against overlapping runs with a plain mkdir lock (portable, no
# flock dependency — not installed by default on macOS) in case one
# invocation (e.g. the first-ever full clone) is still running when the
# next minute's cron fires.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${CACHE_DIR:-$REPO_DIR/.cache}"
LOCK_DIR="$CACHE_DIR/run.lock"
ENV_FILE="$REPO_DIR/.env.local"

mkdir -p "$CACHE_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "$(date -u +%FT%TZ) previous run still in progress, skipping" >&2
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

CACHE_DIR="$CACHE_DIR" "$REPO_DIR/update-smiirl-counter.sh"
