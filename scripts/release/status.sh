#!/usr/bin/env bash
# Monitor the status of a release workflow run.
#
# With no arguments, shows the most recent release workflow run.
# With a tag argument, finds the run triggered by that specific tag.
#
# Usage:
#   ./scripts/release/status.sh                # latest release run
#   ./scripts/release/status.sh v1.1.0-beta.33 # run for specific tag
#   ./scripts/release/status.sh --watch        # live-follow latest run
#   ./scripts/release/status.sh --watch v1.1.0-beta.33
#   ./scripts/release/status.sh --list         # show recent runs

set -euo pipefail

# --- Parse arguments ---
WATCH=false
LIST_MODE=false
TAG=""

for arg in "$@"; do
  case "$arg" in
    --watch|-w) WATCH=true ;;
    --list|-l)  LIST_MODE=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--watch] [--list] [tag]"
      exit 1
      ;;
    *)
      TAG="$arg"
      ;;
  esac
done

# --- List mode ---
if [ "$LIST_MODE" = true ]; then
  echo "=== Recent Release Runs ==="
  gh run list --workflow=release.yml --limit 10
  exit 0
fi

# --- Find the run ---
if [ -n "$TAG" ]; then
  # Find run for a specific tag
  RUN_ID=$(gh run list --workflow=release.yml --limit 20 --json databaseId,headBranch,status \
    -q ".[] | select(.headBranch == \"$TAG\") | .databaseId" | head -1)

  if [ -z "$RUN_ID" ]; then
    echo "Error: No release run found for tag '$TAG'"
    echo ""
    echo "Recent runs:"
    gh run list --workflow=release.yml --limit 5
    exit 1
  fi
else
  # Use the most recent release run
  RUN_ID=$(gh run list --workflow=release.yml --limit 1 --json databaseId -q '.[0].databaseId')

  if [ -z "$RUN_ID" ]; then
    echo "Error: No release workflow runs found."
    exit 1
  fi
fi

# --- Watch or view ---
if [ "$WATCH" = true ]; then
  echo "Watching run $RUN_ID (Ctrl+C to stop)..."
  echo ""
  gh run watch "$RUN_ID"
else
  gh run view "$RUN_ID"
  echo ""

  # Check if still in progress
  STATUS=$(gh run view "$RUN_ID" --json status -q '.status')
  if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
    echo "Run is still $STATUS. Use --watch to follow live:"
    echo "  ./scripts/release/status.sh --watch"
  fi
fi
