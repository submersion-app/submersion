#!/usr/bin/env bash
# Promote a published beta build to the stable channel everywhere.
#
# Thin wrapper over the Promote Beta workflow (.github/workflows/promote.yml):
# verifies the beta exists and shows what will be promoted before dispatching.

set -euo pipefail

usage() {
  cat <<'USAGE'
Promote a published beta build to the stable channel everywhere.

Usage:
  promote.sh <build-number> [options]
  promote.sh --latest [options]

Arguments:
  <build-number>       Beta build number to promote (the last segment of the
                       beta version, e.g. 4957 for v1.7.2.4957)

Options:
  --latest             Promote the newest beta in submersion-app/beta-builds
  --rollout FRACTION   Play production rollout fraction 0.0-1.0 (default 1.0)
  --bump LEVEL         Version bump opening the next beta train:
                       patch | minor | major (default patch)
  -h, --help           Show this help and exit

What promotion does (no rebuilds; the tested beta artifacts ship as-is):
  - Tags main and publishes the stable GitHub release + Sparkle appcast
  - Promotes the identical AAB from the Play beta track to production
  - Submits the existing TestFlight builds for App Review
  - Opens the auto-merging version-bump PR for the next beta train
USAGE
}

BUILD=""
LATEST=false
ROLLOUT="1.0"
BUMP="patch"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --latest) LATEST=true; shift ;;
    --rollout) ROLLOUT="${2:?--rollout requires a value}"; shift 2 ;;
    --bump) BUMP="${2:?--bump requires a value}"; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -n "$BUILD" ]; then
        echo "Unexpected argument: $1" >&2; usage >&2; exit 1
      fi
      BUILD="$1"; shift ;;
  esac
done

case "$BUMP" in patch|minor|major) ;; *)
  echo "Error: --bump must be patch, minor, or major (got: $BUMP)" >&2; exit 1 ;;
esac

# The build number is interpolated into a grep pattern and shipped to the
# promote workflow; anything but digits (e.g. "49.7", where the dot matches
# any character) could silently resolve the wrong release.
require_numeric_build() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: build number must be digits only (got: $1)" >&2
    exit 1
  fi
}

if $LATEST; then
  if [ -n "$BUILD" ]; then
    echo "Error: give either a build number or --latest, not both." >&2
    exit 1
  fi
  TAG=$(gh release view --repo submersion-app/beta-builds --json tagName -q .tagName)
  BUILD="${TAG##*.}"
  require_numeric_build "$BUILD"
elif [ -n "$BUILD" ]; then
  require_numeric_build "$BUILD"
  TAG=$(gh release list --repo submersion-app/beta-builds --json tagName \
    -q ".[].tagName" | grep -E "\.${BUILD}$" | head -1)
  if [ -z "$TAG" ]; then
    echo "Error: no beta release ending in .${BUILD} found in beta-builds." >&2
    exit 1
  fi
else
  usage >&2
  exit 1
fi

BLOCKERS=$(gh issue list --repo submersion-app/submersion \
  --label beta-blocker --state open --json number -q 'length')
if [ "$BLOCKERS" != "0" ]; then
  echo "Error: $BLOCKERS open beta-blocker issue(s). Resolve before promoting." >&2
  exit 1
fi

echo "About to promote $TAG to stable (Play rollout $ROLLOUT, next bump: $BUMP)."
read -r -p "Continue? [y/N] " answer
[ "$answer" = "y" ] || { echo "Aborted."; exit 1; }

gh workflow run promote.yml \
  -f build-number="$BUILD" -f play-rollout="$ROLLOUT" -f next-bump="$BUMP"
echo "Dispatched. Watch with:"
echo "  gh run watch \$(gh run list --workflow=promote.yml --limit 1 --json databaseId -q '.[0].databaseId')"
