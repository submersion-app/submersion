# macOS Release Automation Design

**Date:** 2026-02-13
**Status:** Approved
**Goal:** Fully automate the macOS release process (screenshots + build + upload) to match the iOS pipeline, accessible via a single `bundle exec fastlane full_release` command.

## Problem

iOS has a fully automated release pipeline:
- `capture_screenshots.sh` boots simulators, runs Flutter integration tests, captures screenshots
- iOS Fastfile has `screenshots`, `upload_screenshots`, `build`, `release`, and `full_release` lanes
- One command (`full_release`) does everything

macOS is missing this automation:
- Screenshots use a separate AppleScript + cliclick approach (`capture_macos_screenshots.sh`)
- macOS screenshots are not organized into `en-US/` for Fastlane upload
- macOS Fastfile has only `build`, `beta`, and `release` lanes -- no screenshot support
- No single command for the full release flow

## Approach

**Integration Test Migration** -- Migrate macOS screenshots from AppleScript/cliclick to Flutter integration tests, matching how iOS works. Make `screenshots_test.dart` responsive to platform/layout so it works on both mobile and desktop.

### Alternatives Considered

1. **Wire AppleScript into Fastlane** -- Quick but maintains two different screenshot mechanisms, no UDDF test data in macOS screenshots, requires cliclick dependency and macOS permissions.
2. **Hybrid (integration test data + AppleScript capture)** -- Most complex, two-phase process, still fragile coordinate-based navigation.

## Design

### 1. Integration Test Changes

**File:** `integration_test/screenshots_test.dart`

Make the test responsive to platform/window size:

- Add platform/layout detection: check `Platform.isMacOS` or window width to determine if the app shows NavigationRail (desktop) or BottomNavigationBar (mobile).
- Add `_navigateTo` function (or adapt `_tapBottomNavItem`) that:
  - On mobile: uses existing bottom nav icon tap logic (bottom 20% of screen)
  - On desktop: taps NavigationRail items by finding icons on the left edge of the screen
- On desktop, Equipment and Statistics are direct NavigationRail items (no "More" menu needed), so the "More" menu navigation can be skipped.
- No orientation handling needed for macOS (desktop is always landscape).
- Device name passed via `--dart-define=SCREENSHOT_DEVICE_NAME=macOS`.

### 2. Unified capture_screenshots.sh

**File:** `scripts/release/capture_screenshots.sh`

Replace the macOS AppleScript section (lines 176-206) with the same pattern used for iOS devices:

```bash
flutter test integration_test/screenshots_test.dart \
  -d macos \
  --dart-define=SCREENSHOT_MODE=true \
  --dart-define=SCREENSHOT_DEVICE_NAME=macOS \
  --dart-define=SCREENSHOT_OUTPUT_DIR="$SCREENSHOTS_DIR" \
  --dart-define=UDDF_TEST_DATA_PATH="$UDDF_FILE"
```

Add macOS to the Fastlane organization step:

```bash
organize_device "macOS"
```

This means `capture_screenshots.sh` captures iPhone + iPad + macOS in one run.

### 3. macOS Fastlane Lanes

**File:** `macos/fastlane/Fastfile`

Add lanes matching the iOS Fastfile structure:

| Lane | Description |
|------|-------------|
| `:screenshots` | Runs `flutter test ... -d macos` with dart-defines (macOS only, not the unified script) |
| `:upload_screenshots` | Uploads from `screenshots/` to App Store Connect via `upload_to_app_store` |
| `:capture_and_upload` | Chains `:screenshots` then `:upload_screenshots` |
| `:full_release` | Chains `:screenshots` -> `:upload_screenshots` -> `:release` |
| `:clean_screenshots` | Cleans screenshot directory |
| `:lanes_help` | Lists available lanes |

The `:screenshots` lane runs the integration test directly (not via `capture_screenshots.sh`) so it captures only macOS screenshots when invoked from the macOS Fastfile.

### 4. File Cleanup

**Delete:** `scripts/release/capture_macos_screenshots.sh` -- replaced by integration test approach.

### 5. Screenshot Dimensions

Target: 2560x1600 pixels (via 1280x800 points on Retina). Single size only.

## End-to-End Flows

**macOS full release (single command):**
```bash
cd macos && bundle exec fastlane full_release
```
Captures macOS screenshots -> organizes + alpha-strips -> uploads screenshots -> builds pkg -> uploads pkg.

**iOS full release (unchanged):**
```bash
cd ios && bundle exec fastlane full_release
```

**All-platform screenshots (from project root):**
```bash
./scripts/release/capture_screenshots.sh
```
Captures iPhone + iPad + macOS screenshots, organizes all into `screenshots/en-US/`.

## Risk

Flutter desktop integration tests are untested in this project. If they prove unreliable for macOS screenshot capture (rendering issues, window sizing problems), fall back to wiring the existing AppleScript approach into Fastlane as a quick alternative.
