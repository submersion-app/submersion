# CI/CD Pipeline Overhaul Design

Date: 2026-02-15

## Problem Statement

The Submersion project has a mature multi-platform CI/CD pipeline, but an audit
revealed 12 gaps across build reliability, release friction, and missing
coverage. This design addresses all 12 as a comprehensive overhaul.

## Gap Inventory

| # | Gap | Category |
|---|-----|----------|
| 1 | Flutter version inconsistency (`3.38.5` in ci.yaml vs `3.x` in release/screenshots) | Reliability |
| 2 | Analyze strictness mismatch (`--fatal-infos` in CI vs `--no-fatal-infos` in release preflight) | Reliability |
| 3 | No retry for flaky external calls (notarization, CocoaPods, App Store Connect) | Reliability |
| 4 | Appcast job dependency mismatch (missing `build-ios` in needs array) | Reliability |
| 5 | Two-step release command (bump_version.sh + create_release.sh) | Friction |
| 6 | No curated changelog (only GitHub auto-generated notes) | Friction |
| 7 | No post-release validation (asset presence, checksum verification) | Friction |
| 8 | No Dependabot/Renovate for dependency updates | Coverage |
| 9 | No PR template | Coverage |
| 10 | Coverage threshold not enforced in CI | Coverage |
| 11 | No integration tests in CI | Coverage |
| 12 | No performance regression detection in CI | Coverage |

## Design

### Section 1: Build Reliability (Gaps 1-4)

#### 1.1 Pin Flutter version consistently

Create `.github/flutter-version.txt` containing the pinned version (e.g.,
`3.38.5`). Each workflow reads it via a step:

```yaml
- name: Read Flutter version
  id: flutter-ver
  run: echo "version=$(cat .github/flutter-version.txt)" >> "$GITHUB_OUTPUT"
```

Then uses `${{ steps.flutter-ver.outputs.version }}` in the flutter-action step.
This makes Flutter upgrades a single-file change.

Files changed: `.github/flutter-version.txt` (new), `.github/workflows/ci.yaml`,
`.github/workflows/release.yml`, `.github/workflows/screenshots.yml`.

#### 1.2 Fix analyze strictness mismatch

Change `scripts/release/create_release.sh` line 151 from:

```bash
flutter analyze --no-fatal-infos
```

to:

```bash
flutter analyze --fatal-infos
```

This matches the CI behavior in ci.yaml.

Files changed: `scripts/release/create_release.sh`.

#### 1.3 Add retry logic for flaky external calls

Wrap three steps in release.yml with retry loops:

- **Notarization** (`xcrun notarytool submit`): retry up to 3 times, 30s delay
- **CocoaPods repo update** (`pod repo update`): retry up to 2 times, 15s delay
- **Fastlane uploads** (`bundle exec fastlane`): retry up to 2 times, 30s delay

Implementation uses inline shell retry (no external action dependency):

```bash
for attempt in 1 2 3; do
  <command> && break
  echo "Attempt $attempt failed, retrying in 30s..."
  sleep 30
done
```

Files changed: `.github/workflows/release.yml`.

#### 1.4 Fix appcast dependency mismatch

In release.yml, change the `generate-appcast` job needs from:

```yaml
needs: [build-macos, build-windows, build-linux, build-android]
```

to:

```yaml
needs: [build-macos, build-windows, build-linux, build-android, build-ios]
```

Files changed: `.github/workflows/release.yml`.

### Section 2: Release Friction (Gaps 5-7)

#### 2.1 Unified release command

Create `scripts/release/release.sh` as a porcelain wrapper over existing
plumbing scripts:

```
./scripts/release/release.sh --patch              # bump + changelog + tag + push
./scripts/release/release.sh --minor --beta       # bump + changelog + beta tag + push
./scripts/release/release.sh --dry-run --patch    # show what would happen
```

The script:
1. Calls `bump_version.sh` with the specified bump type and `--commit`
2. Generates a changelog entry via `generate_changelog.sh` (see 2.2)
3. Amends the version bump commit to include the changelog update
4. Calls `create_release.sh` with optional `--beta`/`--rc` flag
5. Prints the `status.sh --watch` command for monitoring

Existing scripts remain independently usable for advanced workflows.

Files changed: `scripts/release/release.sh` (new).

#### 2.2 Changelog generation

Create `scripts/release/generate_changelog.sh` that:

1. Finds the previous tag via `git describe --tags --abbrev=0 HEAD~1`
2. Parses commits between previous tag and HEAD using `git log --format`
3. Groups by conventional commit type (feat, fix, refactor, etc.)
4. Prepends a new version section to `CHANGELOG.md`
5. Also outputs a markdown snippet for the GitHub Release body

In release.yml, replace `generate_release_notes: true` with explicit notes from
the generated changelog via `--notes-file`.

No external tools. Pure shell script matching existing style.

Files changed: `scripts/release/generate_changelog.sh` (new), `CHANGELOG.md` (new),
`.github/workflows/release.yml`.

#### 2.3 Post-release validation

Add a `validate-release` job at the end of release.yml (after `create-release`):

1. Verify all expected assets exist on the GitHub Release (DMG, ZIP, tar.gz,
   APK, appcast.xml, checksums-sha256.txt)
2. Download artifacts and verify SHA-256 checksums match
3. Validate appcast.xml is well-formed XML

Files changed: `.github/workflows/release.yml`.

### Section 3: Missing Coverage (Gaps 8-12)

#### 3.1 Dependabot configuration

Create `.github/dependabot.yml` with three ecosystems:

- **github-actions**: weekly, all workflow actions
- **pub**: weekly, Dart/Flutter packages, limit 5 open PRs
- **bundler**: monthly, Fastlane gems in `/ios` and `/macos`

Files changed: `.github/dependabot.yml` (new).

#### 3.2 PR template

Create `.github/PULL_REQUEST_TEMPLATE.md` with sections for Summary, Changes,
Test Plan (checklist), and Screenshots.

Files changed: `.github/PULL_REQUEST_TEMPLATE.md` (new).

#### 3.3 Coverage threshold enforcement

Two changes:

1. In ci.yaml, change Codecov step to `fail_ci_if_error: true`
2. Create `codecov.yml` at repo root:
   - Project target: 70% (ratchet up over time)
   - Patch target: 80% (matches CLAUDE.md requirement for new code)
   - Threshold: 5% (allows minor fluctuations)

Files changed: `.github/workflows/ci.yaml`, `codecov.yml` (new).

#### 3.4 Integration tests in CI

Add an `integration-test` job to ci.yaml:

- Runs on `macos-14` (required for Flutter desktop integration tests)
- PR-only (`if: github.event_name == 'pull_request'`) to save runner minutes
- Screenshot mode disabled (testing correctness, not capturing images)
- Depends on the `analyze` job (same as `test`)

Files changed: `.github/workflows/ci.yaml`.

#### 3.5 Performance regression detection

Create `.github/workflows/performance.yml`:

- Scheduled weekly (Monday 6am UTC) plus manual dispatch
- Runs `flutter test --tags performance` on macOS runner
- Uploads results as artifacts with 90-day retention
- No benchmark tracking dashboard (YAGNI; test pass/fail is the signal)

Files changed: `.github/workflows/performance.yml` (new).

## Files Summary

| File | Action |
|------|--------|
| `.github/flutter-version.txt` | Create |
| `.github/dependabot.yml` | Create |
| `.github/PULL_REQUEST_TEMPLATE.md` | Create |
| `.github/workflows/ci.yaml` | Modify |
| `.github/workflows/release.yml` | Modify |
| `.github/workflows/screenshots.yml` | Modify |
| `.github/workflows/performance.yml` | Create |
| `codecov.yml` | Create |
| `CHANGELOG.md` | Create |
| `scripts/release/release.sh` | Create |
| `scripts/release/generate_changelog.sh` | Create |
| `scripts/release/create_release.sh` | Modify |

Total: 7 new files, 5 modified files.
