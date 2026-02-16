# CI/CD Pipeline Overhaul Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Address 12 gaps in build reliability, release friction, and missing coverage across the CI/CD pipeline.

**Architecture:** Pure infrastructure changes -- no Dart code modified. All changes are GitHub Actions workflows, shell scripts, and config files. Tasks are ordered so that quick config fixes come first (tasks 1-4), followed by new scripts (tasks 5-7), and finally CI workflow additions (tasks 8-12).

**Tech Stack:** GitHub Actions, Bash, Codecov, Dependabot

---

### Task 1: Pin Flutter version via shared config file

**Files:**
- Create: `.github/flutter-version.txt`
- Modify: `.github/workflows/ci.yaml:13-14`
- Modify: `.github/workflows/release.yml:22-23`
- Modify: `.github/workflows/screenshots.yml:28-29`

**Step 1: Create the version file**

Create `.github/flutter-version.txt` with a single line:

```
3.38.5
```

No trailing newline. This is the single source of truth for Flutter version.

**Step 2: Update ci.yaml to read from version file**

In `.github/workflows/ci.yaml`, replace lines 13-14:

```yaml
env:
  FLUTTER_VERSION: '3.38.5'
```

with:

```yaml
env:
  FLUTTER_VERSION_FILE: '.github/flutter-version.txt'
```

Then in every job (`analyze`, `test`, `build-ios`, `build-macos`, `build-android`, `build-linux`, `build-windows`), add a step immediately after `actions/checkout` and before `subosito/flutter-action`:

```yaml
      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"
```

And change every `flutter-version: ${{ env.FLUTTER_VERSION }}` to `flutter-version: ${{ steps.flutter-ver.outputs.version }}`.

**Step 3: Update release.yml to read from version file**

In `.github/workflows/release.yml`, replace lines 22-23:

```yaml
env:
  FLUTTER_VERSION: '3.x'
```

with:

```yaml
env:
  FLUTTER_VERSION_FILE: '.github/flutter-version.txt'
```

Add the same "Read Flutter version" step after checkout in every job (`build-macos`, `build-windows`, `build-linux`, `build-android`, `build-ios`). Change every `flutter-version: ${{ env.FLUTTER_VERSION }}` to `flutter-version: ${{ steps.flutter-ver.outputs.version }}`.

**Step 4: Update screenshots.yml to read from version file**

Same pattern in `.github/workflows/screenshots.yml`. Replace `FLUTTER_VERSION: '3.x'` (line 29) with `FLUTTER_VERSION_FILE`. Add read step after checkout in `capture-ios`, `capture-macos` jobs. Update flutter-action references.

**Step 5: Verify YAML is valid**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml')); print('ci.yaml OK')"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('release.yml OK')"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/screenshots.yml')); print('screenshots.yml OK')"
```

Expected: All three print OK.

**Step 6: Commit**

```bash
git add .github/flutter-version.txt .github/workflows/ci.yaml .github/workflows/release.yml .github/workflows/screenshots.yml
git commit -m "ci: pin Flutter version via shared config file

All workflows now read Flutter version from .github/flutter-version.txt
instead of hardcoding it. Eliminates version drift between CI and release."
```

---

### Task 2: Fix analyze strictness mismatch

**Files:**
- Modify: `scripts/release/create_release.sh:151`

**Step 1: Fix the flag**

In `scripts/release/create_release.sh`, change line 151 from:

```bash
  if flutter analyze --no-fatal-infos > /dev/null 2>&1; then
```

to:

```bash
  if flutter analyze --fatal-infos > /dev/null 2>&1; then
```

This makes the release preflight match CI's `flutter analyze --fatal-infos` (ci.yaml line 49).

**Step 2: Verify the script is still valid bash**

Run:
```bash
bash -n scripts/release/create_release.sh
```

Expected: No output (clean parse).

**Step 3: Commit**

```bash
git add scripts/release/create_release.sh
git commit -m "fix: match analyze strictness between CI and release preflight

Release preflight now uses --fatal-infos to match ci.yaml behavior.
Previously used --no-fatal-infos which could let infos-level issues
slip through to release."
```

---

### Task 3: Add retry logic for flaky external calls in release.yml

**Files:**
- Modify: `.github/workflows/release.yml:132-144` (notarization)
- Modify: `.github/workflows/release.yml:212-219` (macOS Fastlane upload)
- Modify: `.github/workflows/release.yml:487-494` (iOS Fastlane upload)

**Step 1: Add retry to notarization step**

In `.github/workflows/release.yml`, replace the "Notarize DMG" step body (lines 138-144) with:

```yaml
        run: |
          DMG="Submersion-${TAG_NAME}-macOS.dmg"
          for attempt in 1 2 3; do
            if xcrun notarytool submit "$DMG" \
                --apple-id "$APPLE_ID" \
                --password "$APPLE_APP_PASSWORD" \
                --team-id "$APPLE_TEAM_ID" \
                --wait; then
              break
            fi
            if [ "$attempt" -eq 3 ]; then
              echo "Notarization failed after 3 attempts"
              exit 1
            fi
            echo "Notarization attempt $attempt failed, retrying in 30s..."
            sleep 30
          done
          xcrun stapler staple "$DMG"
```

**Step 2: Add retry to macOS Fastlane upload**

In the "Upload to App Store / TestFlight" step for macOS (line 219), change:

```yaml
        run: bundle exec fastlane "$FASTLANE_LANE"
```

to:

```yaml
        run: |
          for attempt in 1 2; do
            if bundle exec fastlane "$FASTLANE_LANE"; then
              break
            fi
            if [ "$attempt" -eq 2 ]; then
              echo "Fastlane upload failed after 2 attempts"
              exit 1
            fi
            echo "Fastlane attempt $attempt failed, retrying in 30s..."
            sleep 30
          done
```

**Step 3: Add retry to iOS Fastlane upload**

Apply the same retry wrapper to the iOS "Build and upload iOS" step (line 494):

```yaml
        run: |
          for attempt in 1 2; do
            if bundle exec fastlane "$FASTLANE_LANE"; then
              break
            fi
            if [ "$attempt" -eq 2 ]; then
              echo "Fastlane upload failed after 2 attempts"
              exit 1
            fi
            echo "Fastlane attempt $attempt failed, retrying in 30s..."
            sleep 30
          done
```

**Step 4: Verify YAML validity**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('OK')"
```

Expected: OK.

**Step 5: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add retry logic for notarization and Fastlane uploads

Notarization retries 3x with 30s delay. Fastlane uploads retry 2x
with 30s delay. Handles transient Apple/App Store Connect failures."
```

---

### Task 4: Fix appcast dependency mismatch

**Files:**
- Modify: `.github/workflows/release.yml:521`

**Step 1: Add build-ios to appcast needs**

In `.github/workflows/release.yml`, change line 521 from:

```yaml
    needs: [build-macos, build-windows, build-linux, build-android]
```

to:

```yaml
    needs: [build-macos, build-windows, build-linux, build-android, build-ios]
```

**Step 2: Verify YAML validity**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('OK')"
```

Expected: OK.

**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "fix: include build-ios in appcast job dependencies

Appcast generation now waits for all 5 platform builds including iOS.
Previously missing build-ios could let appcast generate even when
the iOS build failed."
```

---

### Task 5: Create changelog generation script

**Files:**
- Create: `scripts/release/generate_changelog.sh`
- Create: `CHANGELOG.md`

**Step 1: Create the changelog generator**

Create `scripts/release/generate_changelog.sh`:

```bash
#!/usr/bin/env bash
# Generate changelog entries from conventional commits.
#
# Parses commits since the previous tag, groups by type, and either
# prepends to CHANGELOG.md or outputs a markdown snippet for GitHub Release notes.
#
# Usage:
#   ./scripts/release/generate_changelog.sh                # prepend to CHANGELOG.md
#   ./scripts/release/generate_changelog.sh --notes-only   # output release notes to stdout
#   ./scripts/release/generate_changelog.sh --dry-run      # preview without writing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"

# --- Parse arguments ---
NOTES_ONLY=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --notes-only) NOTES_ONLY=true ;;
    --dry-run)    DRY_RUN=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--notes-only] [--dry-run]"
      exit 1
      ;;
  esac
done

# --- Determine version and tag range ---
VERSION_LINE=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml")
FULL_VERSION=$(echo "$VERSION_LINE" | sed 's/version: *//')
SEMVER=$(echo "$FULL_VERSION" | cut -d'+' -f1)

PREV_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")
if [ -z "$PREV_TAG" ]; then
  RANGE="HEAD"
  RANGE_DESC="all commits"
else
  RANGE="${PREV_TAG}..HEAD"
  RANGE_DESC="commits since $PREV_TAG"
fi

# --- Collect commits by type ---
declare -A SECTIONS
SECTIONS=(
  [feat]="Features"
  [fix]="Bug Fixes"
  [refactor]="Refactoring"
  [perf]="Performance"
  [docs]="Documentation"
  [test]="Tests"
  [ci]="CI/CD"
  [chore]="Chores"
)

# Ordered keys for consistent output
ORDERED_KEYS=(feat fix refactor perf docs test ci chore)

declare -A ENTRIES

for key in "${ORDERED_KEYS[@]}"; do
  ENTRIES[$key]=""
done

OTHER_ENTRIES=""

while IFS= read -r line; do
  [ -z "$line" ] && continue

  MATCHED=false
  for key in "${ORDERED_KEYS[@]}"; do
    if echo "$line" | grep -qE "^${key}(\(.*\))?:"; then
      # Strip the type prefix for cleaner display
      MSG=$(echo "$line" | sed -E "s/^${key}(\(.*\))?: *//")
      ENTRIES[$key]+="- ${MSG}"$'\n'
      MATCHED=true
      break
    fi
  done

  if [ "$MATCHED" = false ]; then
    OTHER_ENTRIES+="- ${line}"$'\n'
  fi
done < <(git log "$RANGE" --format='%s' --no-merges 2>/dev/null)

# --- Build markdown ---
DATE=$(date +%Y-%m-%d)
NOTES="## ${SEMVER} (${DATE})"$'\n'$'\n'

HAS_CONTENT=false
for key in "${ORDERED_KEYS[@]}"; do
  if [ -n "${ENTRIES[$key]}" ]; then
    NOTES+="### ${SECTIONS[$key]}"$'\n'$'\n'
    NOTES+="${ENTRIES[$key]}"$'\n'
    HAS_CONTENT=true
  fi
done

if [ -n "$OTHER_ENTRIES" ]; then
  NOTES+="### Other"$'\n'$'\n'
  NOTES+="$OTHER_ENTRIES"$'\n'
  HAS_CONTENT=true
fi

if [ "$HAS_CONTENT" = false ]; then
  NOTES+="No notable changes."$'\n'
fi

# --- Output ---
if [ "$DRY_RUN" = true ]; then
  echo "[Dry run] Would generate changelog for $RANGE_DESC"
  echo ""
  echo "$NOTES"
  exit 0
fi

if [ "$NOTES_ONLY" = true ]; then
  echo "$NOTES"
  exit 0
fi

# Prepend to CHANGELOG.md
if [ -f "$CHANGELOG" ]; then
  EXISTING=$(cat "$CHANGELOG")
  echo -e "${NOTES}\n${EXISTING}" > "$CHANGELOG"
else
  echo -e "# Changelog\n\n${NOTES}" > "$CHANGELOG"
fi

echo "Updated $CHANGELOG with ${SEMVER} entry ($RANGE_DESC)"
```

**Step 2: Make it executable**

Run:
```bash
chmod +x scripts/release/generate_changelog.sh
```

**Step 3: Create initial CHANGELOG.md**

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to Submersion are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).
```

**Step 4: Test the script**

Run:
```bash
./scripts/release/generate_changelog.sh --dry-run
```

Expected: Prints grouped commits since last tag without modifying any files.

**Step 5: Commit**

```bash
git add scripts/release/generate_changelog.sh CHANGELOG.md
git commit -m "feat: add changelog generation from conventional commits

New generate_changelog.sh parses git log, groups by commit type,
and outputs markdown for CHANGELOG.md or GitHub Release notes."
```

---

### Task 6: Create unified release script

**Files:**
- Create: `scripts/release/release.sh`

**Step 1: Create the script**

Create `scripts/release/release.sh`:

```bash
#!/usr/bin/env bash
# Unified release command: bump version, generate changelog, tag, push.
#
# Orchestrates bump_version.sh, generate_changelog.sh, and create_release.sh
# into a single command.
#
# Usage:
#   ./scripts/release/release.sh --patch              # patch release
#   ./scripts/release/release.sh --minor              # minor release
#   ./scripts/release/release.sh --major              # major release
#   ./scripts/release/release.sh --build              # build number only
#   ./scripts/release/release.sh --patch --beta       # beta pre-release
#   ./scripts/release/release.sh --patch --rc         # release candidate
#   ./scripts/release/release.sh --dry-run --patch    # preview
#   ./scripts/release/release.sh --patch --skip-preflight

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse arguments ---
BUMP_TYPE=""
PRERELEASE_LABEL=""
DRY_RUN=false
SKIP_PREFLIGHT=false

for arg in "$@"; do
  case "$arg" in
    --major|--minor|--patch|--build) BUMP_TYPE="$arg" ;;
    --beta)            PRERELEASE_LABEL="--beta" ;;
    --rc)              PRERELEASE_LABEL="--rc" ;;
    --alpha)           PRERELEASE_LABEL="--alpha" ;;
    --dry-run)         DRY_RUN=true ;;
    --skip-preflight)  SKIP_PREFLIGHT=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--major|--minor|--patch|--build] [--beta|--rc|--alpha] [--dry-run] [--skip-preflight]"
      exit 1
      ;;
  esac
done

if [ -z "$BUMP_TYPE" ]; then
  echo "Error: No bump type specified."
  echo "Usage: $0 [--major|--minor|--patch|--build] [--beta|--rc|--alpha] [--dry-run] [--skip-preflight]"
  exit 1
fi

echo "=== Submersion Release ==="
echo ""

# --- Step 1: Bump version ---
echo "--- Step 1: Bump version ($BUMP_TYPE) ---"
if [ "$DRY_RUN" = true ]; then
  "$SCRIPT_DIR/bump_version.sh" "$BUMP_TYPE" --dry-run
else
  "$SCRIPT_DIR/bump_version.sh" "$BUMP_TYPE" --commit
fi
echo ""

# --- Step 2: Generate changelog ---
echo "--- Step 2: Generate changelog ---"
if [ "$DRY_RUN" = true ]; then
  "$SCRIPT_DIR/generate_changelog.sh" --dry-run
else
  "$SCRIPT_DIR/generate_changelog.sh"

  # Amend the version bump commit to include changelog
  git add CHANGELOG.md
  git commit --amend --no-edit
  echo "Amended version bump commit with changelog update"
fi
echo ""

# --- Step 3: Create release tag and push ---
echo "--- Step 3: Create release ---"

CREATE_ARGS=()
[ -n "$PRERELEASE_LABEL" ] && CREATE_ARGS+=("$PRERELEASE_LABEL")
[ "$DRY_RUN" = true ] && CREATE_ARGS+=("--dry-run")
[ "$SKIP_PREFLIGHT" = true ] && CREATE_ARGS+=("--skip-preflight")

"$SCRIPT_DIR/create_release.sh" "${CREATE_ARGS[@]}"

echo ""
if [ "$DRY_RUN" = false ]; then
  echo "=== Release initiated ==="
  echo ""
  echo "Monitor progress:"
  echo "  ./scripts/release/status.sh --watch"
fi
```

**Step 2: Make it executable**

Run:
```bash
chmod +x scripts/release/release.sh
```

**Step 3: Test dry-run**

Run:
```bash
./scripts/release/release.sh --patch --dry-run
```

Expected: Shows version bump preview, changelog preview, and tag creation preview without modifying anything.

**Step 4: Commit**

```bash
git add scripts/release/release.sh
git commit -m "feat: add unified release script

Orchestrates bump_version.sh, generate_changelog.sh, and
create_release.sh into a single command. Supports --dry-run,
pre-release labels, and --skip-preflight."
```

---

### Task 7: Update release.yml to use changelog for release notes and add post-release validation

**Files:**
- Modify: `.github/workflows/release.yml:563-598` (create-release job)

**Step 1: Add changelog-based release notes to create-release job**

In the `create-release` job, add a checkout step and changelog generation step before the "Create GitHub Release" step. Replace the current create-release job steps (lines 570-598) with:

```yaml
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate release notes
        id: notes
        run: |
          chmod +x scripts/release/generate_changelog.sh
          NOTES=$(./scripts/release/generate_changelog.sh --notes-only)
          # Write to file for gh-release action
          echo "$NOTES" > release-notes.md

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          merge-multiple: true

      - name: List artifacts
        run: ls -la

      - name: Determine if pre-release
        id: prerelease
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          if echo "$TAG_NAME" | grep -qE '\-(beta|rc|alpha)'; then
            echo "prerelease=true" >> "$GITHUB_OUTPUT"
          else
            echo "prerelease=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            Submersion-*
            appcast.xml
            checksums-sha256.txt
          prerelease: ${{ steps.prerelease.outputs.prerelease }}
          body_path: release-notes.md
```

Note: `generate_release_notes: true` is replaced by `body_path: release-notes.md`.

**Step 2: Add validate-release job**

Append this new job at the end of release.yml:

```yaml
  # ============================================================================
  # Validate Release
  # ============================================================================
  validate-release:
    name: Validate Release
    needs: create-release
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Verify release assets
        env:
          TAG_NAME: ${{ github.ref_name }}
          GH_TOKEN: ${{ github.token }}
        run: |
          echo "=== Verifying release assets for $TAG_NAME ==="

          ASSETS=$(gh release view "$TAG_NAME" \
            --repo "${{ github.repository }}" \
            --json assets -q '.assets[].name')

          MISSING=()
          for expected in \
            "Submersion-${TAG_NAME}-macOS.dmg" \
            "Submersion-${TAG_NAME}-Windows.zip" \
            "Submersion-${TAG_NAME}-Linux.tar.gz" \
            "Submersion-${TAG_NAME}-Android.apk" \
            "appcast.xml" \
            "checksums-sha256.txt"; do
            if echo "$ASSETS" | grep -q "$expected"; then
              echo "  [OK] $expected"
            else
              echo "  [MISSING] $expected"
              MISSING+=("$expected")
            fi
          done

          if [ ${#MISSING[@]} -gt 0 ]; then
            echo ""
            echo "ERROR: ${#MISSING[@]} expected asset(s) missing from release"
            exit 1
          fi

          echo ""
          echo "All expected assets present."

      - name: Verify checksums
        env:
          TAG_NAME: ${{ github.ref_name }}
          GH_TOKEN: ${{ github.token }}
        run: |
          echo "=== Verifying checksums ==="
          gh release download "$TAG_NAME" \
            --repo "${{ github.repository }}" \
            --pattern "checksums-sha256.txt" \
            --pattern "Submersion-*"

          if sha256sum -c checksums-sha256.txt; then
            echo "All checksums verified."
          else
            echo "ERROR: Checksum verification failed"
            exit 1
          fi

      - name: Validate appcast XML
        env:
          TAG_NAME: ${{ github.ref_name }}
          GH_TOKEN: ${{ github.token }}
        run: |
          echo "=== Validating appcast.xml ==="
          gh release download "$TAG_NAME" \
            --repo "${{ github.repository }}" \
            --pattern "appcast.xml" \
            --clobber

          if python3 -c "import xml.etree.ElementTree as ET; ET.parse('appcast.xml'); print('Valid XML')"; then
            echo "Appcast is well-formed."
          else
            echo "ERROR: appcast.xml is not valid XML"
            exit 1
          fi
```

**Step 3: Verify YAML validity**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml')); print('OK')"
```

Expected: OK.

**Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: use changelog for release notes and add post-release validation

Release notes now come from generate_changelog.sh instead of GitHub
auto-generation. New validate-release job checks all assets are
present, checksums verify, and appcast.xml is well-formed."
```

---

### Task 8: Add Dependabot configuration

**Files:**
- Create: `.github/dependabot.yml`

**Step 1: Create Dependabot config**

Create `.github/dependabot.yml`:

```yaml
# Automated dependency updates
# See: https://docs.github.com/en/code-security/dependabot/dependabot-version-updates

version: 2
updates:
  # GitHub Actions -- weekly, security-critical
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "ci"

  # Dart/Flutter pub packages -- weekly
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    commit-message:
      prefix: "chore"

  # Ruby/Bundler (Fastlane) -- monthly, changes infrequently
  - package-ecosystem: "bundler"
    directories:
      - "/ios"
      - "/macos"
    schedule:
      interval: "monthly"
    commit-message:
      prefix: "chore"
```

**Step 2: Commit**

```bash
git add .github/dependabot.yml
git commit -m "ci: add Dependabot for GitHub Actions, pub, and Bundler

Weekly updates for Actions and pub packages, monthly for Fastlane gems.
Commit messages follow conventional commits format."
```

---

### Task 9: Add PR template

**Files:**
- Create: `.github/PULL_REQUEST_TEMPLATE.md`

**Step 1: Create PR template**

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Summary

<!-- What does this PR do and why? -->

## Changes

<!-- Bullet list of key changes -->

-

## Test Plan

- [ ] `flutter test` passes
- [ ] `flutter analyze` passes
- [ ] Manual testing on: <!-- list platforms tested -->

## Screenshots

<!-- If UI changes, add before/after screenshots. Delete this section if not applicable. -->
```

**Step 2: Commit**

```bash
git add .github/PULL_REQUEST_TEMPLATE.md
git commit -m "docs: add PR template with test plan checklist"
```

---

### Task 10: Enforce coverage threshold

**Files:**
- Modify: `.github/workflows/ci.yaml:91`
- Create: `codecov.yml`

**Step 1: Enable Codecov failure in CI**

In `.github/workflows/ci.yaml`, change line 91 from:

```yaml
          fail_ci_if_error: false
```

to:

```yaml
          fail_ci_if_error: true
```

**Step 2: Create Codecov config**

Create `codecov.yml` at the repo root:

```yaml
# Codecov configuration
# See: https://docs.codecov.com/docs/codecov-yaml

coverage:
  status:
    project:
      default:
        target: 70%
        threshold: 5%
    patch:
      default:
        target: 80%

ignore:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "test/**"
  - "integration_test/**"
```

**Step 3: Verify YAML validity**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('codecov.yml')); print('OK')"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml')); print('OK')"
```

Expected: Both OK.

**Step 4: Commit**

```bash
git add .github/workflows/ci.yaml codecov.yml
git commit -m "ci: enforce coverage threshold via Codecov

Project target: 70% (ratchet up over time). Patch target: 80%
(new code in PRs). Codecov now fails CI on upload errors.
Ignores generated code and test files."
```

---

### Task 11: Add integration tests to CI

**Files:**
- Modify: `.github/workflows/ci.yaml` (add new job after `test`)

**Step 1: Add integration-test job**

In `.github/workflows/ci.yaml`, add this new job between the `test` job and `build-ios` job:

```yaml
  integration-test:
    name: Integration Test (macOS)
    needs: analyze
    runs-on: macos-14
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4

      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: 'latest-stable'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ steps.flutter-ver.outputs.version }}
          channel: 'stable'
          cache: true

      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.pub-cache
            ${{ github.workspace }}/.dart_tool
          key: pub-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-

      - name: Disable code signing for CI
        run: |
          echo 'CODE_SIGNING_ALLOWED = NO' >> macos/Runner/Configs/Debug.xcconfig
          echo 'CODE_SIGNING_REQUIRED = NO' >> macos/Runner/Configs/Debug.xcconfig
          echo 'CODE_SIGN_IDENTITY = ' >> macos/Runner/Configs/Debug.xcconfig

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Run integration tests
        run: |
          flutter test integration_test/ \
            -d macos \
            --dart-define=SCREENSHOT_MODE=false
```

**Step 2: Verify YAML validity**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yaml')); print('OK')"
```

Expected: OK.

**Step 3: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "ci: add integration tests on macOS for pull requests

Runs integration_test/ suite on macOS runner for PRs only.
Screenshot mode disabled -- testing correctness, not capturing images."
```

---

### Task 12: Add performance regression detection workflow

**Files:**
- Create: `.github/workflows/performance.yml`

**Step 1: Create the workflow**

Create `.github/workflows/performance.yml`:

```yaml
# Weekly Performance Benchmarks
#
# Runs performance-tagged tests on a schedule to detect regressions.
# Also available via manual dispatch for on-demand testing.

name: Performance Benchmarks

on:
  schedule:
    - cron: '0 6 * * 1'  # Monday 6am UTC
  workflow_dispatch:

concurrency:
  group: performance
  cancel-in-progress: true

env:
  FLUTTER_VERSION_FILE: '.github/flutter-version.txt'

jobs:
  benchmark:
    name: Run Performance Tests
    runs-on: macos-14
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Read Flutter version
        id: flutter-ver
        run: echo "version=$(cat ${{ env.FLUTTER_VERSION_FILE }})" >> "$GITHUB_OUTPUT"

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: 'latest-stable'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ steps.flutter-ver.outputs.version }}
          channel: stable
          cache: true

      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.pub-cache
            ${{ github.workspace }}/.dart_tool
          key: pub-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: |
            pub-${{ runner.os }}-

      - name: Install dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Run performance tests
        run: flutter test --tags performance

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: perf-results-${{ github.run_number }}
          path: |
            test/performance/results/
          retention-days: 90
          if-no-files-found: ignore
```

**Step 2: Verify YAML validity**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/performance.yml')); print('OK')"
```

Expected: OK.

**Step 3: Commit**

```bash
git add .github/workflows/performance.yml
git commit -m "ci: add weekly performance benchmark workflow

Runs performance-tagged tests every Monday 6am UTC on macOS.
Also supports manual dispatch. Results uploaded as artifacts
with 90-day retention."
```

---

### Task 13: Final verification and summary commit

**Step 1: Verify all workflows parse correctly**

Run:
```bash
for f in .github/workflows/*.y*ml; do
  python3 -c "import yaml; yaml.safe_load(open('$f')); print('OK: $f')"
done
```

Expected: All files print OK.

**Step 2: Verify all scripts are executable**

Run:
```bash
ls -la scripts/release/*.sh
```

Expected: All .sh files have execute permission.

**Step 3: Run local test suite to confirm no breakage**

Run:
```bash
flutter test
```

Expected: All tests pass (no Dart code was changed).

**Step 4: Verify dart format (no Dart changes expected, but confirm)**

Run:
```bash
dart format --set-exit-if-changed lib/ test/
```

Expected: No changes needed.

**Step 5: Review full diff**

Run:
```bash
git log --oneline HEAD~12..HEAD
```

Expected: 12 commits, one per task, all with conventional commit prefixes.
