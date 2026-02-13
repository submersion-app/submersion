# macOS Release Automation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fully automate the macOS release process (screenshots + build + upload) via a single Fastlane command, by migrating macOS screenshots from AppleScript to Flutter integration tests.

**Architecture:** Make the existing `screenshots_test.dart` responsive to desktop layout (NavigationRail vs BottomNav), add screenshot/upload lanes to the macOS Fastfile, update the unified capture script, and remove the old AppleScript-based approach.

**Tech Stack:** Flutter integration tests, Fastlane (Ruby), Bash shell scripts

**Design doc:** `docs/plans/2026-02-13-macos-release-automation-design.md`

---

### Task 1: Update XIB Window Size for App Store Screenshot Dimensions

The macOS window defaults to 1280x720. App Store Connect requires 2560x1600 pixel screenshots (1280x800 points on Retina 2x). Update the XIB to 1280x800.

**Files:**
- Modify: `macos/Runner/Base.lproj/MainMenu.xib:335` (contentRect height)
- Modify: `macos/Runner/Base.lproj/MainMenu.xib:338` (frame height)

**Step 1: Update contentRect height**

In `MainMenu.xib`, line 335, change:
```xml
<rect key="contentRect" x="335" y="390" width="1280" height="720"/>
```
to:
```xml
<rect key="contentRect" x="335" y="390" width="1280" height="800"/>
```

**Step 2: Update frame height**

In `MainMenu.xib`, line 338, change:
```xml
<rect key="frame" x="0.0" y="0.0" width="1280" height="720"/>
```
to:
```xml
<rect key="frame" x="0.0" y="0.0" width="1280" height="800"/>
```

**Step 3: Verify the app builds and launches**

Run: `flutter build macos --release`
Then: `open build/macos/Build/Products/Release/Submersion.app`
Expected: Window opens at 1280x800 points. NavigationRail is visible in extended mode (1280 >= 1200).

**Step 4: Commit**

```bash
git add macos/Runner/Base.lproj/MainMenu.xib
git commit -m "chore: update macOS window size to 1280x800 for App Store screenshots"
```

---

### Task 2: Make Integration Test Navigation Responsive

The existing `screenshots_test.dart` uses `_tapBottomNavItem` which only works on mobile (bottom nav). Add desktop NavigationRail support.

**Files:**
- Modify: `integration_test/screenshots_test.dart`

**Step 1: Add platform detection import and constant**

At the top of `screenshots_test.dart`, after the existing imports (around line 16), add:
```dart
import 'dart:io' show Platform;
```

Note: `dart:io` is already imported on line 16 for `File`. Change that import to also expose `Platform`:
```dart
import 'dart:io';
```
(This already imports both `File` and `Platform`.)

**Step 2: Add NavigationRail tap helper**

After the existing `_tapBottomNavItem` function (ends at line 565), add a new helper for tapping NavigationRail items on desktop:

```dart
/// Taps a NavigationRail item by its icon on desktop layout.
/// Uses position filtering to ensure we tap icons on the left edge (rail area),
/// not icons elsewhere in the UI.
Future<void> _tapNavRailItem(WidgetTester tester, IconData icon) async {
  // NavigationRail is on the left side of the screen, within the first ~200px
  const railMaxX = 200.0;

  final iconFinder = find.byIcon(icon);
  Widget? targetIcon = _findIconInNavRail(tester, iconFinder, railMaxX);

  // If not found, try the selected (filled) variant
  if (targetIcon == null) {
    final selectedIcon = _getSelectedIcon(icon);
    if (selectedIcon != null) {
      final selectedFinder = find.byIcon(selectedIcon);
      targetIcon = _findIconInNavRail(tester, selectedFinder, railMaxX);
    }
  }

  if (targetIcon != null) {
    await tester.tap(find.byWidget(targetIcon), warnIfMissed: false);
    await _settle(tester);
  } else if (iconFinder.evaluate().isNotEmpty) {
    // Fallback: tap first icon found
    await tester.tap(iconFinder.first, warnIfMissed: false);
    await _settle(tester);
  }
}

/// Finds an icon widget positioned in the NavigationRail area (left edge).
Widget? _findIconInNavRail(
  WidgetTester tester,
  Finder finder,
  double railMaxX,
) {
  for (final element in finder.evaluate()) {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      if (position.dx <= railMaxX) {
        return element.widget;
      }
    }
  }
  return null;
}
```

**Step 3: Add unified navigation function**

Add a function that picks the right navigation method based on platform:

```dart
/// Whether we are running on a desktop platform (macOS, Windows, Linux).
bool get _isDesktop =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Navigates to a screen using the appropriate navigation method.
/// On desktop: taps NavigationRail icon directly.
/// On mobile: taps BottomNavigationBar icon.
Future<void> _navigateTo(WidgetTester tester, IconData icon) async {
  if (_isDesktop) {
    await _tapNavRailItem(tester, icon);
  } else {
    await _tapBottomNavItem(tester, icon);
  }
}
```

**Step 4: Update the test body to use `_navigateTo` and handle desktop layout**

Replace the navigation calls in the main test body. The key differences on desktop:
- Equipment and Statistics are directly in the NavigationRail (no "More" menu)
- NavigationRail icons: `Icons.backpack_outlined` for Equipment (rail index 4), `Icons.bar_chart_outlined` for Statistics (rail index 9)

Update the navigation calls in the `'Capture all screens'` test:

1. Line ~162: Replace `await _tapBottomNavItem(tester, Icons.scuba_diving_outlined);`
   with: `await _navigateTo(tester, Icons.scuba_diving_outlined);`

2. Line ~232: Replace `await _tapBottomNavItem(tester, Icons.location_on_outlined);`
   with: `await _navigateTo(tester, Icons.location_on_outlined);`

3. Lines ~427-465 (Equipment via "More" menu): Replace with platform-aware logic:
```dart
// 6. Navigate to Equipment
if (_isDesktop) {
  // Desktop: Equipment is directly in NavigationRail
  await _navigateTo(tester, Icons.backpack_outlined);
  await screenshotHelper.waitForContent(tester);

  // Select an equipment item to show detail pane
  final equipmentListView = find.byType(ListView);
  if (equipmentListView.evaluate().isNotEmpty) {
    final equipmentCards = find.descendant(
      of: equipmentListView.first,
      matching: find.byType(Card),
    );
    if (equipmentCards.evaluate().length > 1) {
      final cardIndex = min(2, equipmentCards.evaluate().length - 1);
      await tester.tap(equipmentCards.at(cardIndex));
      await _settle(tester);
      await screenshotHelper.waitForContent(
        tester,
        duration: const Duration(seconds: 1),
      );
    }
  }
  await screenshotHelper.takeScreenshot(tester, 'equipment');
} else {
  // Mobile: Equipment is under "More" menu
  await _tapBottomNavItem(tester, Icons.more_horiz_outlined);
  await _settle(tester);
  final equipmentText = find.text('Equipment');
  if (equipmentText.evaluate().isNotEmpty) {
    await tester.tap(equipmentText.first);
    await _settle(tester);
    await screenshotHelper.waitForContent(tester);

    final equipmentListView = find.byType(ListView);
    if (equipmentListView.evaluate().isNotEmpty) {
      final equipmentCards = find.descendant(
        of: equipmentListView.first,
        matching: find.byType(Card),
      );
      if (equipmentCards.evaluate().length > 1) {
        final cardIndex = min(2, equipmentCards.evaluate().length - 1);
        await tester.tap(equipmentCards.at(cardIndex));
        await _settle(tester);
        await screenshotHelper.waitForContent(
          tester,
          duration: const Duration(seconds: 1),
        );
      }
    }
    await screenshotHelper.takeScreenshot(tester, 'equipment');
  }
}
```

4. Lines ~467-480 (Statistics via "More" menu): Replace similarly:
```dart
// 7. Navigate to Statistics
if (_isDesktop) {
  await _navigateTo(tester, Icons.bar_chart_outlined);
  await screenshotHelper.waitForContent(
    tester,
    duration: const Duration(seconds: 2),
  );
  await screenshotHelper.takeScreenshot(tester, 'statistics');
} else {
  await _tapBottomNavItem(tester, Icons.more_horiz_outlined);
  await _settle(tester);
  final statisticsText = find.text('Statistics');
  if (statisticsText.evaluate().isNotEmpty) {
    await tester.tap(statisticsText.first);
    await _settle(tester);
    await screenshotHelper.waitForContent(
      tester,
      duration: const Duration(seconds: 2),
    );
    await screenshotHelper.takeScreenshot(tester, 'statistics');
  }
}
```

5. For the map view navigation (section 5, lines ~239-425): The map icon button approach should work on both platforms since it finds `IconButton` by icon, not by position in bottom nav. No changes needed.

6. For the Records section (~lines 482-501): Records may appear differently on desktop. Use the same approach -- try finding Records text directly first:
```dart
// 8. Records (same on both platforms - found by text)
final recordsText = find.text('Records');
if (recordsText.evaluate().isNotEmpty) {
  await tester.tap(recordsText.first);
  await _settle(tester);
  await screenshotHelper.waitForContent(tester);
  await screenshotHelper.takeScreenshot(tester, 'records');
} else if (!_isDesktop) {
  // Mobile only: try via More menu
  await _tapBottomNavItem(tester, Icons.more_horiz_outlined);
  await _settle(tester);
  final recordsInMore = find.text('Records');
  if (recordsInMore.evaluate().isNotEmpty) {
    await tester.tap(recordsInMore.first);
    await _settle(tester);
    await screenshotHelper.waitForContent(tester);
    await screenshotHelper.takeScreenshot(tester, 'records');
  }
}
```

**Step 5: Run the test on macOS**

Run: `flutter test integration_test/screenshots_test.dart -d macos --dart-define=SCREENSHOT_MODE=true --dart-define=SCREENSHOT_DEVICE_NAME=macOS --dart-define=SCREENSHOT_OUTPUT_DIR=screenshots --dart-define=UDDF_TEST_DATA_PATH=integration_test/fixtures/screenshot_test_data.uddf`
Expected: Test runs, navigates via NavigationRail, screenshots saved to `screenshots/macOS/`.

If the test hangs, check whether `pumpAndSettle` (we use manual pump loops to avoid this) or infinite animations are the cause. The existing `_settle()` helper with frame-based pumping should work.

If window size is wrong (not 1280x800), verify the XIB change from Task 1 took effect.

**Step 6: Verify iOS tests still pass**

Run the iOS screenshot test on a simulator to confirm the responsive navigation didn't break mobile:
Run: `flutter test integration_test/screenshots_test.dart -d "iPhone 15 Pro Max" --dart-define=SCREENSHOT_MODE=true --dart-define=SCREENSHOT_DEVICE_NAME=iPhone_6_7_inch --dart-define=SCREENSHOT_OUTPUT_DIR=screenshots`
Expected: Test passes, screenshots saved to `screenshots/iPhone_6_7_inch/`.

**Step 7: Commit**

```bash
git add integration_test/screenshots_test.dart
git commit -m "feat: make screenshot integration test responsive to desktop NavigationRail"
```

---

### Task 3: Update capture_screenshots.sh for macOS Integration Tests

Replace the AppleScript-based macOS section with the same integration test pattern used for iOS.

**Files:**
- Modify: `scripts/release/capture_screenshots.sh:175-206` (macOS section)
- Modify: `scripts/release/capture_screenshots.sh:281-282` (organize section)

**Step 1: Replace the macOS screenshot section**

In `capture_screenshots.sh`, replace lines 175-206 (the macOS section that calls `capture_macos_screenshots.sh`) with:

```bash
# ==========================================
# macOS Screenshots
# ==========================================
echo "=========================================="
echo "Processing: macOS"
echo "=========================================="

if [[ "$(uname)" == "Darwin" ]]; then
  echo "Running macOS screenshot capture via integration test..."
  cd "$PROJECT_ROOT"

  flutter test integration_test/screenshots_test.dart \
    -d macos \
    --dart-define=SCREENSHOT_MODE=true \
    --dart-define=SCREENSHOT_DEVICE_NAME=macOS \
    --dart-define=SCREENSHOT_OUTPUT_DIR="$SCREENSHOTS_DIR" \
    --dart-define=UDDF_TEST_DATA_PATH="$UDDF_FILE" \
    2>&1 || {
      echo "Warning: macOS screenshot capture encountered issues"
    }

  echo "Completed: macOS"
else
  echo "Warning: Not running on macOS. Skipping macOS screenshots."
fi
echo ""
```

**Step 2: Add macOS to the organize section**

After line 282 (`organize_device "iPad_13_inch"`), add:
```bash
organize_device "macOS"
```

**Step 3: Test the unified script**

Run: `./scripts/release/capture_screenshots.sh`
Expected: Script runs iPhone + iPad + macOS screenshots. macOS screenshots appear in `screenshots/macOS/` and get organized into `screenshots/en-US/` with alpha stripped.

Note: For a quick test of just the macOS portion, you can comment out the iOS device loop temporarily.

**Step 4: Commit**

```bash
git add scripts/release/capture_screenshots.sh
git commit -m "feat: replace AppleScript macOS screenshots with integration tests in unified script"
```

---

### Task 4: Add Screenshot and Release Lanes to macOS Fastfile

Add the missing lanes to the macOS Fastfile to match the iOS Fastfile structure.

**Files:**
- Modify: `macos/fastlane/Fastfile`

**Step 1: Add screenshot lanes**

After the `load_api_key` method (line 50) and before the build lanes section (line 52), add:

```ruby
  # ============================================================================
  # Screenshot Lanes
  # ============================================================================

  desc "Capture Mac App Store screenshots via integration test"
  lane :screenshots do
    UI.message("Starting macOS screenshot capture...")

    screenshots_dir = File.absolute_path("../../screenshots")
    uddf_file = File.absolute_path("../../integration_test/fixtures/screenshot_test_data.uddf")

    # Generate UDDF test data
    generate_script = File.absolute_path("../../scripts/generate_uddf_test_data.py")
    if File.exist?(generate_script)
      sh("python3 '#{generate_script}' -o '#{uddf_file}'") rescue UI.message("Warning: Failed to generate UDDF test data")
    end

    # Run integration test on macOS
    sh("cd ../.. && flutter test integration_test/screenshots_test.dart " \
       "-d macos " \
       "--dart-define=SCREENSHOT_MODE=true " \
       "--dart-define=SCREENSHOT_DEVICE_NAME=macOS " \
       "--dart-define=SCREENSHOT_OUTPUT_DIR=#{screenshots_dir} " \
       "--dart-define=UDDF_TEST_DATA_PATH=#{uddf_file}")

    UI.success("macOS screenshots captured successfully!")
    UI.message("Screenshots saved to: #{screenshots_dir}/macOS/")
  end

  desc "Upload screenshots to Mac App Store Connect"
  lane :upload_screenshots do
    screenshots_path = File.absolute_path("../../screenshots")

    unless File.directory?(screenshots_path)
      UI.user_error!("Screenshots directory not found at #{screenshots_path}. Run 'fastlane screenshots' first.")
    end

    api_key = load_api_key

    UI.message("Uploading macOS screenshots to App Store Connect...")

    upload_to_app_store(
      api_key: api_key,
      skip_binary_upload: true,
      skip_metadata: true,
      skip_app_version_update: true,
      screenshots_path: screenshots_path,
      overwrite_screenshots: true,
      ignore_language_directory_validation: true,
      precheck_include_in_app_purchases: false,
      force: true,
    )

    UI.success("macOS screenshots uploaded successfully!")
  end

  desc "Capture screenshots and upload to App Store Connect"
  lane :capture_and_upload do
    screenshots
    upload_screenshots
  end
```

**Step 2: Add full_release lane**

After the existing `:release` lane (line ~118), add:

```ruby
  desc "Full release: capture screenshots, upload everything, and submit build"
  lane :full_release do
    screenshots
    upload_screenshots
    release
  end
```

**Step 3: Add utility lanes**

At the end of the `platform :mac do` block, before `end`:

```ruby
  # ============================================================================
  # Utility Lanes
  # ============================================================================

  desc "Clean up screenshot directories"
  lane :clean_screenshots do
    screenshots_path = "../../screenshots"

    if File.directory?(screenshots_path)
      FileUtils.rm_rf(screenshots_path)
      UI.success("Cleaned screenshots directory")
    else
      UI.message("No screenshots directory to clean")
    end
  end

  desc "Clean build artifacts"
  lane :clean do
    sh("cd ../.. && flutter clean")
    clear_derived_data

    build_path = "./build"
    if File.directory?(build_path)
      FileUtils.rm_rf(build_path)
      UI.message("Cleaned build directory")
    end

    UI.success("All build artifacts cleaned!")
  end

  desc "Show all available lanes"
  lane :lanes_help do
    UI.message("Available Fastlane lanes:")
    UI.message("")
    UI.message("  Screenshots:")
    UI.message("    screenshots        - Capture Mac App Store screenshots")
    UI.message("    upload_screenshots - Upload screenshots to App Store Connect")
    UI.message("    capture_and_upload - Both in one command")
    UI.message("")
    UI.message("  Build & Release:")
    UI.message("    build              - Build pkg for Mac App Store")
    UI.message("    beta               - Build + upload to TestFlight")
    UI.message("    release            - Build + upload to App Store")
    UI.message("    full_release       - Screenshots + build + upload")
    UI.message("")
    UI.message("  Utilities:")
    UI.message("    clean              - Clean all build artifacts")
    UI.message("    clean_screenshots  - Clean screenshot directory")
    UI.message("    lanes_help         - Show this help")
  end
```

**Step 4: Verify Fastlane can parse the file**

Run: `cd macos && bundle exec fastlane lanes_help`
Expected: Lists all available lanes without errors.

**Step 5: Test the screenshots lane**

Run: `cd macos && bundle exec fastlane screenshots`
Expected: Generates UDDF data, runs integration test, captures macOS screenshots.

**Step 6: Commit**

```bash
git add macos/fastlane/Fastfile
git commit -m "feat: add screenshot capture, upload, and full_release lanes to macOS Fastfile"
```

---

### Task 5: Update organize_screenshots_for_fastlane.sh for macOS

The standalone organize script also needs macOS support.

**Files:**
- Modify: `scripts/release/organize_screenshots_for_fastlane.sh`

**Step 1: Add macOS organization block**

After the iPad section (line ~91), add:

```bash
# Process macOS screenshots
if [ -d "$SCREENSHOTS_DIR/macOS" ]; then
    echo "Processing macOS -> $LOCALE/"

    for file in "$SCREENSHOTS_DIR/macOS"/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "  $filename"
            strip_alpha "$file" "$SCREENSHOTS_DIR/$LOCALE/$filename"
        fi
    done
    echo "  Done!"
fi
```

**Step 2: Update the closing instructions**

Change line 99 from:
```bash
echo "You can now run: cd ios && bundle exec fastlane upload_screenshots"
```
to:
```bash
echo "You can now upload screenshots:"
echo "  iOS:   cd ios && bundle exec fastlane upload_screenshots"
echo "  macOS: cd macos && bundle exec fastlane upload_screenshots"
```

**Step 3: Commit**

```bash
git add scripts/release/organize_screenshots_for_fastlane.sh
git commit -m "feat: add macOS screenshot organization for Fastlane"
```

---

### Task 6: Delete Old AppleScript Screenshot Script

**Files:**
- Delete: `scripts/release/capture_macos_screenshots.sh`

**Step 1: Remove the file**

```bash
git rm scripts/release/capture_macos_screenshots.sh
```

**Step 2: Commit**

```bash
git commit -m "chore: remove AppleScript-based macOS screenshot script (replaced by integration tests)"
```

---

### Task 7: End-to-End Verification

Run the full macOS release flow to verify everything works together.

**Step 1: Clean screenshots**

```bash
cd macos && bundle exec fastlane clean_screenshots
```

**Step 2: Run macOS full_release (dry run -- skip actual upload)**

For testing, run just the screenshot capture portion:
```bash
cd macos && bundle exec fastlane screenshots
```

**Step 3: Verify screenshots**

Check: `ls screenshots/macOS/`
Expected: `macOS_01_dashboard.png`, `macOS_02_dive_list.png`, `macOS_03_dive_detail.png`, etc.

Check screenshot dimensions:
```bash
sips -g pixelWidth -g pixelHeight screenshots/macOS/macOS_01_dashboard.png
```
Expected: `pixelWidth: 2560`, `pixelHeight: 1600` (on Retina display).

**Step 4: Verify Fastlane organization**

Run the organize step manually to confirm macOS screenshots get into `en-US/`:
```bash
./scripts/release/organize_screenshots_for_fastlane.sh
ls screenshots/en-US/ | grep macOS
```
Expected: macOS PNG files present in `en-US/` directory.

**Step 5: Run unified capture script**

```bash
./scripts/release/capture_screenshots.sh
```
Expected: Captures iPhone + iPad + macOS screenshots. All organized into `en-US/`.

**Step 6: Verify iOS screenshots still work**

```bash
cd ios && bundle exec fastlane screenshots
```
Expected: iOS screenshots captured successfully, no regressions.

---

### Task 8: Format and Final Commit

**Step 1: Format all Dart code**

```bash
dart format lib/ test/ integration_test/
```

**Step 2: Run analyzer**

```bash
flutter analyze
```
Expected: No new issues.

**Step 3: Run unit tests**

```bash
flutter test
```
Expected: All existing tests pass.

**Step 4: Final commit if any formatting changes**

```bash
git add -A && git commit -m "chore: format code"
```
