#!/usr/bin/env bash
# Delete a GitHub release, its remote tag, and its local tag.
#
# Usage:
#   ./scripts/release/delete_release.sh <tag>        # delete specific release
#   ./scripts/release/delete_release.sh --list        # list all releases
#   ./scripts/release/delete_release.sh --dry-run <tag>
#
# Examples:
#   ./scripts/release/delete_release.sh v1.1.0.33
#   ./scripts/release/delete_release.sh v1.0.0-beta.31

set -euo pipefail

# --- Parse arguments ---
DRY_RUN=false
TAG=""
LIST_MODE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --list|-l) LIST_MODE=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--dry-run] [--list] <tag>"
      exit 1
      ;;
    *)
      TAG="$arg"
      ;;
  esac
done

# --- List mode ---
if [ "$LIST_MODE" = true ]; then
  echo "=== GitHub Releases ==="
  gh release list --limit 20
  echo ""
  echo "=== Local Tags ==="
  git tag -l 'v*' --sort=-version:refname | head -20
  exit 0
fi

# --- Validate tag argument ---
if [ -z "$TAG" ]; then
  echo "Error: No tag specified."
  echo ""
  echo "Usage: $0 [--dry-run] <tag>"
  echo ""
  echo "Available releases:"
  gh release list --limit 10 2>/dev/null || true
  exit 1
fi

echo "=== Delete Release ==="
echo "Tag: $TAG"
echo ""

# --- Check what exists ---
HAS_LOCAL_TAG=false
HAS_REMOTE_TAG=false
HAS_GH_RELEASE=false

if git tag -l "$TAG" | grep -q "$TAG"; then
  HAS_LOCAL_TAG=true
fi

if git ls-remote --tags origin "refs/tags/$TAG" 2>/dev/null | grep -q "$TAG"; then
  HAS_REMOTE_TAG=true
fi

if gh release view "$TAG" &>/dev/null; then
  HAS_GH_RELEASE=true
fi

echo "  Local tag:      $([ "$HAS_LOCAL_TAG" = true ] && echo "exists" || echo "not found")"
echo "  Remote tag:     $([ "$HAS_REMOTE_TAG" = true ] && echo "exists" || echo "not found")"
echo "  GitHub release: $([ "$HAS_GH_RELEASE" = true ] && echo "exists" || echo "not found")"
echo ""

if [ "$HAS_LOCAL_TAG" = false ] && [ "$HAS_REMOTE_TAG" = false ] && [ "$HAS_GH_RELEASE" = false ]; then
  echo "Nothing to delete for tag '$TAG'."
  exit 0
fi

# --- Dry run ---
if [ "$DRY_RUN" = true ]; then
  [ "$HAS_GH_RELEASE" = true ] && echo "[Dry run] Would delete GitHub release: $TAG"
  [ "$HAS_REMOTE_TAG" = true ]  && echo "[Dry run] Would delete remote tag: $TAG"
  [ "$HAS_LOCAL_TAG" = true ]   && echo "[Dry run] Would delete local tag: $TAG"
  exit 0
fi

# --- Confirm ---
read -rp "Delete all of the above for '$TAG'? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# --- Delete (order: GitHub release first, then remote tag, then local tag) ---
if [ "$HAS_GH_RELEASE" = true ]; then
  echo "Deleting GitHub release '$TAG'..."
  gh release delete "$TAG" --yes
fi

if [ "$HAS_REMOTE_TAG" = true ]; then
  echo "Deleting remote tag '$TAG'..."
  git push origin --delete --no-verify "$TAG"
fi

if [ "$HAS_LOCAL_TAG" = true ]; then
  echo "Deleting local tag '$TAG'..."
  git tag -d "$TAG"
fi

echo ""
echo "=== Done ==="
echo "Release '$TAG' has been fully removed."
