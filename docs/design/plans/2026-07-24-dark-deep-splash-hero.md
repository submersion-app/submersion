# Dark "Deep" Splash Screen and Hero Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In dark mode, the startup splash and the dashboard hero bar render an "Abyss Blue" deep-ocean version of the animated ocean background — same animations, only colors change.

**Architecture:** Swap the dark-branch palette inside the shared `OceanBackground` widget; add a tiny pure resolver (`resolveStartupBrightness`) that reads a SharedPreferences mirror of the diver's theme-mode setting so the splash (which renders before the database opens) and the setup wizard can resolve dark mode; write the mirror through from the settings notifier on every change and every hydration.

**Tech Stack:** Flutter 3.x, Riverpod, SharedPreferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-07-24-dark-deep-splash-hero-design.md`

## Global Constraints

- Abyss Blue dark gradient, copied verbatim from the spec: `Color(0xFF0B2540)` -> `Color(0xFF08243A).withValues(alpha: 0.9)` -> `Color(0xFF041220).withValues(alpha: 0.85)`, top-left to bottom-right.
- Dark bubble color stays white at 0.10 alpha; dark caustic opacity stays 0.06 (the values the current dark branch already uses — do not change them).
- Light-mode palette must not change: `Color(0xFF00ACC1)` -> `Color(0xFF00ACC1).withValues(alpha: 0.9)` -> `Color(0xFF009688).withValues(alpha: 0.85)`.
- Bubble specs, speeds, wobble, caustic drift: byte-for-byte unchanged.
- SharedPreferences key is exactly `cached_theme_mode`; values are exactly `system` | `light` | `dark`.
- No emojis anywhere. No new user-facing strings (so no l10n work).
- After each task: code must pass `dart format .` with no changes (run it; commit any reformat with the task).
- `flutter analyze` must be run on the whole project and must be clean — never pipe it through `tail` or any filter, and treat infos as fatal (CI does).
- Commit messages: conventional-commit style, no attribution footers, no session links.

## Worktree Setup (before Task 1)

Feature work goes in its own worktree. Create it with the superpowers:using-git-worktrees skill (branch name `feature/dark-deep-splash`), then — mandatory for this repo — inside the new worktree run:

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Worktrees do not inherit submodules, build artifacts, or generated Drift code from the main checkout; skipping these steps causes confusing analyzer and test failures unrelated to this feature.

---

### Task 1: Startup brightness resolver

**Files:**
- Create: `lib/core/presentation/startup_brightness.dart`
- Test: `test/core/presentation/startup_brightness_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces (used by Tasks 3, 4, 5):
  - `const String cachedThemeModeKey = 'cached_theme_mode';`
  - `String cachedThemeModeValue(ThemeMode mode)` — returns `'system' | 'light' | 'dark'`.
  - `Brightness resolveStartupBrightness(SharedPreferences prefs, Brightness platformBrightness)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/presentation/startup_brightness_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/presentation/startup_brightness.dart';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveStartupBrightness', () {
    test('cached light wins over a dark platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'light'});
      expect(
        resolveStartupBrightness(prefs, Brightness.dark),
        Brightness.light,
      );
    });

    test('cached dark wins over a light platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'dark'});
      expect(
        resolveStartupBrightness(prefs, Brightness.light),
        Brightness.dark,
      );
    });

    test('cached system follows the platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'system'});
      expect(
        resolveStartupBrightness(prefs, Brightness.light),
        Brightness.light,
      );
      expect(
        resolveStartupBrightness(prefs, Brightness.dark),
        Brightness.dark,
      );
    });

    test('missing key follows the platform', () async {
      final prefs = await _prefsWith({});
      expect(
        resolveStartupBrightness(prefs, Brightness.dark),
        Brightness.dark,
      );
      expect(
        resolveStartupBrightness(prefs, Brightness.light),
        Brightness.light,
      );
    });

    test('unrecognized value follows the platform', () async {
      final prefs = await _prefsWith({cachedThemeModeKey: 'blue'});
      expect(
        resolveStartupBrightness(prefs, Brightness.dark),
        Brightness.dark,
      );
    });
  });

  group('cachedThemeModeValue', () {
    test('round-trips every ThemeMode through the resolver', () async {
      const cases = {
        (ThemeMode.light, Brightness.dark): Brightness.light,
        (ThemeMode.dark, Brightness.light): Brightness.dark,
        (ThemeMode.system, Brightness.dark): Brightness.dark,
        (ThemeMode.system, Brightness.light): Brightness.light,
      };
      for (final entry in cases.entries) {
        final (mode, platform) = entry.key;
        final prefs = await _prefsWith({
          cachedThemeModeKey: cachedThemeModeValue(mode),
        });
        expect(resolveStartupBrightness(prefs, platform), entry.value);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/presentation/startup_brightness_test.dart`
Expected: FAIL — compile error, `package:submersion/core/presentation/startup_brightness.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/presentation/startup_brightness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key mirroring the active diver's theme-mode setting.
///
/// The authoritative setting lives in the per-diver settings table, which is
/// unavailable while the startup splash is showing (the database is not open
/// yet). The settings notifier writes this mirror on every change and every
/// hydration, so it is stale for at most one launch after a restore or sync
/// changes the setting behind the app's back.
const String cachedThemeModeKey = 'cached_theme_mode';

/// Serializes [mode] for storage under [cachedThemeModeKey].
String cachedThemeModeValue(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'system',
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
};

/// Resolves the brightness the app will use once its theme loads, for
/// surfaces that render before the database opens (startup splash, setup
/// wizard). A missing or unrecognized cached value falls back to
/// [platformBrightness].
Brightness resolveStartupBrightness(
  SharedPreferences prefs,
  Brightness platformBrightness,
) {
  return switch (prefs.getString(cachedThemeModeKey)) {
    'light' => Brightness.light,
    'dark' => Brightness.dark,
    _ => platformBrightness,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/presentation/startup_brightness_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/presentation/startup_brightness.dart test/core/presentation/startup_brightness_test.dart
git commit -m "feat(core): add startup brightness resolver with cached theme mode"
```

---

### Task 2: Abyss Blue dark palette in OceanBackground

**Files:**
- Modify: `lib/core/presentation/widgets/ocean_background.dart:100-110` (the `gradientColors` ternary in `_OceanBackgroundState.build`)
- Test: `test/core/presentation/widgets/ocean_background_test.dart` (new file)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `OceanBackground` renders the Abyss Blue gradient whenever its effective brightness is dark. Widget API is unchanged (`OceanBackground({required Widget child, BorderRadius borderRadius, Brightness? brightness})`); Tasks 4 and 5 rely on the existing `brightness` parameter.

- [ ] **Step 1: Write the failing test**

Create `test/core/presentation/widgets/ocean_background_test.dart`. Note: never `pumpAndSettle` here — the widget animates forever; plain `pump()` is enough for these assertions.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/ocean_background.dart';

const _abyssTop = Color(0xFF0B2540);
const _lightTop = Color(0xFF00ACC1);

Future<void> _pumpBackground(
  WidgetTester tester, {
  Brightness? override,
  required Brightness themeBrightness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: themeBrightness),
      home: OceanBackground(
        brightness: override,
        child: const SizedBox.expand(),
      ),
    ),
  );
  await tester.pump();
}

LinearGradient _gradientOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(OceanBackground),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.gradient! as LinearGradient;
}

void main() {
  testWidgets('dark theme renders the Abyss Blue gradient', (tester) async {
    await _pumpBackground(tester, themeBrightness: Brightness.dark);
    final gradient = _gradientOf(tester);
    expect(gradient.colors, [
      _abyssTop,
      const Color(0xFF08243A).withValues(alpha: 0.9),
      const Color(0xFF041220).withValues(alpha: 0.85),
    ]);
  });

  testWidgets('light theme renders the existing teal gradient', (
    tester,
  ) async {
    await _pumpBackground(tester, themeBrightness: Brightness.light);
    final gradient = _gradientOf(tester);
    expect(gradient.colors, [
      _lightTop,
      const Color(0xFF00ACC1).withValues(alpha: 0.9),
      const Color(0xFF009688).withValues(alpha: 0.85),
    ]);
  });

  testWidgets('brightness override beats the ambient theme both ways', (
    tester,
  ) async {
    await _pumpBackground(
      tester,
      override: Brightness.light,
      themeBrightness: Brightness.dark,
    );
    expect(_gradientOf(tester).colors.first, _lightTop);

    await _pumpBackground(
      tester,
      override: Brightness.dark,
      themeBrightness: Brightness.light,
    );
    expect(_gradientOf(tester).colors.first, _abyssTop);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/presentation/widgets/ocean_background_test.dart`
Expected: the two light-mode assertions pass; the dark assertions FAIL because the current dark gradient starts with `Color(0xFF00838F)`.

- [ ] **Step 3: Swap the dark palette**

In `lib/core/presentation/widgets/ocean_background.dart`, replace the dark branch of `gradientColors` (currently the teal `0xFF00838F` / `0xFF00796B` list) with:

```dart
    final gradientColors = isDark
        ? [
            // Abyss Blue: the deep-ocean dark palette.
            const Color(0xFF0B2540),
            const Color(0xFF08243A).withValues(alpha: 0.9),
            const Color(0xFF041220).withValues(alpha: 0.85),
          ]
        : [
            const Color(0xFF00ACC1),
            const Color(0xFF00ACC1).withValues(alpha: 0.9),
            const Color(0xFF009688).withValues(alpha: 0.85),
          ];
```

Leave `bubbleColor` (dark: white at 0.10) and `causticOpacity` (dark: 0.06) exactly as they are.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/presentation/widgets/ocean_background_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/presentation/widgets/ocean_background.dart test/core/presentation/widgets/ocean_background_test.dart
git commit -m "feat(core): swap OceanBackground dark palette to Abyss Blue"
```

---

### Task 3: Write the theme-mode cache through from the settings notifier

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`_loadSettings` around lines 881-908, `_saveSettings` around lines 938-970)
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart` (add a group; reuse the file's existing private fakes)

**Interfaces:**
- Consumes (Task 1): `cachedThemeModeKey`, `cachedThemeModeValue(ThemeMode)`.
- Produces: `cached_theme_mode` is guaranteed written after every settings hydration and every settings save. No API changes.

- [ ] **Step 1: Write the failing tests**

In `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, add these imports at the top (the file already imports flutter_test, shared_preferences, and settings_providers):

```dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:submersion/core/presentation/startup_brightness.dart';
```

Then add this group inside `main()`, alongside the existing groups. It reuses the file's private `_InMemorySettingsRepository`, `_EmptyDiverRepository`, and `_NullDiverIdNotifier` helpers and copies the existing group's setUp pattern (including the settle delay — the notifier's constructor runs async initialization that must finish before assertions):

```dart
  group('Real SettingsNotifier cached theme mode', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diverSettingsRepositoryProvider.overrideWithValue(
            _InMemorySettingsRepository(),
          ),
          diverRepositoryProvider.overrideWithValue(_EmptyDiverRepository()),
          currentDiverIdProvider.overrideWith((ref) => _NullDiverIdNotifier()),
        ],
      );
      // Construct the notifier and let async _initializeAndLoad settle.
      container.read(settingsProvider);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() {
      container.dispose();
    });

    test('hydration writes the default theme mode into prefs', () {
      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getString(cachedThemeModeKey), 'system');
    });

    test('setThemeMode mirrors the new value into prefs', () async {
      final notifier = container.read(settingsProvider.notifier);
      final prefs = container.read(sharedPreferencesProvider);

      await notifier.setThemeMode(ThemeMode.dark);
      expect(prefs.getString(cachedThemeModeKey), 'dark');

      await notifier.setThemeMode(ThemeMode.light);
      expect(prefs.getString(cachedThemeModeKey), 'light');

      await notifier.setThemeMode(ThemeMode.system);
      expect(prefs.getString(cachedThemeModeKey), 'system');
    });
  });
```

Note the container/provider names above must match the existing group's setUp exactly — if the existing file spells any of them differently, follow the file, not this plan.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: the two new tests FAIL (`prefs.getString(cachedThemeModeKey)` returns null); all pre-existing tests still pass.

- [ ] **Step 3: Implement the write-through**

In `lib/features/settings/presentation/providers/settings_providers.dart`:

1. Add the import:

```dart
import 'package:submersion/core/presentation/startup_brightness.dart';
```

2. Add a private helper method inside `SettingsNotifier`:

```dart
  /// Mirrors the effective theme mode into SharedPreferences so the startup
  /// splash and setup wizard (which render before the database opens) can
  /// resolve dark mode. See resolveStartupBrightness.
  Future<void> _writeCachedThemeMode(SharedPreferences prefs) async {
    await prefs.setString(
      cachedThemeModeKey,
      cachedThemeModeValue(state.themeMode),
    );
  }
```

3. Call it from `_loadSettings()` in **both** state-assignment branches:
   - In the no-diver branch, after `state = AppSettings(...)` and before the `return;`:

```dart
        await _writeCachedThemeMode(prefs);
        return;
```

   - After the diver-loaded assignment `state = settings.copyWith(...)` (before `_scheduleNotificationsIfNeeded()`):

```dart
      await _writeCachedThemeMode(prefs);
```

4. Call it from `_saveSettings()` after the perdix overlay writes (it already has a local `prefs`):

```dart
    await _writeCachedThemeMode(prefs);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS, including all pre-existing tests in the file.

Also run the broader settings provider tests to catch harness regressions:

Run: `flutter test test/features/settings/presentation/providers/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/presentation/providers/settings_notifier_real_test.dart
git commit -m "feat(settings): mirror theme mode into prefs for pre-db surfaces"
```

---

### Task 4: Splash resolves and passes brightness

**Files:**
- Modify: `lib/core/presentation/pages/startup_page.dart:541` (the `isDark` computation in `_StartupWrapperState.build`) and `:584` (the splash `OceanBackground`)
- Test: `test/core/presentation/pages/startup_page_test.dart` (add two tests to the existing `StartupWrapper lifecycle` group)

**Interfaces:**
- Consumes (Task 1): `cachedThemeModeKey`, `resolveStartupBrightness`. Consumes (Task 2): `OceanBackground.brightness`.
- Produces: the splash and its error screens key off the resolved brightness. No API changes.

- [ ] **Step 1: Write the failing tests**

In `test/core/presentation/pages/startup_page_test.dart`, add imports:

```dart
import 'package:submersion/core/presentation/startup_brightness.dart';
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
```

Add to the existing `StartupWrapper lifecycle` group (it provides `prefs`, `logFileService`, `locationService` via setUp; the new tests re-seed prefs where needed):

```dart
    testWidgets('splash renders dark when cached theme mode is dark', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({cachedThemeModeKey: 'dark'});
      prefs = await SharedPreferences.getInstance();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) => Completer<void>().future,
        ),
      );
      await tester.pump();

      final background = tester.widget<OceanBackground>(
        find.byType(OceanBackground),
      );
      expect(background.brightness, Brightness.dark);

      // Drain the 1-second splash delay timer to avoid pending timer errors.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('splash follows platform brightness when cache is absent', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        _buildStartupWrapper(
          prefs: prefs,
          logFileService: logFileService,
          locationService: locationService,
          schemaVersionProbeOverride: (_) =>
              (needsMigration: false, totalSteps: 0),
          initializerOverride: (_) => Completer<void>().future,
        ),
      );
      await tester.pump();

      final background = tester.widget<OceanBackground>(
        find.byType(OceanBackground),
      );
      expect(background.brightness, Brightness.dark);

      await tester.pump(const Duration(seconds: 2));
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: both new tests FAIL — `background.brightness` is currently null (nothing passes it). Pre-existing tests still pass.

- [ ] **Step 3: Implement the wiring**

In `lib/core/presentation/pages/startup_page.dart`:

1. Add the import:

```dart
import 'package:submersion/core/presentation/startup_brightness.dart';
```

2. Replace the `isDark` line at the top of `build` (currently `final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;`) with:

```dart
    final brightness = resolveStartupBrightness(
      widget.prefs,
      MediaQuery.platformBrightnessOf(context),
    );
    final isDark = brightness == Brightness.dark;
```

(`isDark` continues to drive the error-screen colors, so those now agree with the splash automatically.)

3. Pass the brightness to the splash background (the `Scaffold` with `key: const ValueKey('splash')`):

```dart
                        body: OceanBackground(
                          brightness: brightness,
                          child: SafeArea(
                            child: Center(child: _buildSplashContent(isDark)),
                          ),
                        ),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/presentation/pages/startup_page_test.dart`
Expected: PASS, including all pre-existing tests.

Also run: `flutter test test/core/presentation/pages/`
Expected: PASS (backup-flow and step-timing tests are unaffected).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/presentation/pages/startup_page.dart test/core/presentation/pages/startup_page_test.dart
git commit -m "feat(startup): resolve splash brightness from cached theme mode"
```

---

### Task 5: Setup wizard follows the resolved brightness

**Files:**
- Modify: `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart:233-237` (the `Scaffold` body's `OceanBackground`)
- Test: `test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart` (add one test)

**Interfaces:**
- Consumes (Task 1): `resolveStartupBrightness`. Consumes: `sharedPreferencesProvider` from `settings_providers.dart` (already overridden by the test helper `getBaseOverrides()` in `test/helpers/mock_providers.dart`, so existing wizard tests keep passing).
- Produces: wizard background brightness matches the splash. No API changes.

- [ ] **Step 1: Write the failing test**

In `test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`, add the import:

```dart
import 'package:submersion/core/presentation/widgets/ocean_background.dart';
```

Add this test inside `main()`, following the file's existing `getBaseOverrides()` / `testApp` / `pumpWizard` pattern:

```dart
  testWidgets('wizard ocean background follows resolved brightness', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: const SetupWizardPage(mode: SetupWizardMode.firstRun),
      ),
    );
    await pumpWizard(tester);

    final background = tester.widget<OceanBackground>(
      find.byType(OceanBackground),
    );
    expect(background.brightness, Brightness.dark);
  });
```

(`getBaseOverrides()` seeds empty SharedPreferences, so there is no cached theme mode and the resolver falls back to the platform brightness we set to dark.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart`
Expected: the new test FAILS — `background.brightness` is currently the pinned `Brightness.light`. Pre-existing tests still pass.

- [ ] **Step 3: Implement the wizard change**

In `lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart`:

1. Add imports:

```dart
import 'package:submersion/core/presentation/startup_brightness.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
```

2. In `build`, before the `return Scaffold(...)`, resolve the brightness:

```dart
    final oceanBrightness = resolveStartupBrightness(
      ref.watch(sharedPreferencesProvider),
      MediaQuery.platformBrightnessOf(context),
    );
```

3. Replace the pinned brightness on the `OceanBackground` (and update its comment):

```dart
      body: OceanBackground(
        // Resolve brightness the same way the startup splash does, so the
        // background does not visibly shift when the splash dissolves into
        // the wizard.
        brightness: oceanBrightness,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/setup_wizard/`
Expected: PASS. Caveats from this repo's history: the wizard gaining a provider dependency is a known way to break sibling tests — if any fail with an `UnimplementedError` from `sharedPreferencesProvider`, add `sharedPreferencesProvider.overrideWithValue(prefs)` to that test's overrides the same way `getBaseOverrides()` does. Some iCloud tile-tap tests only run on Apple platforms; skipped tests on other hosts are expected.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/setup_wizard/presentation/pages/setup_wizard_page.dart test/features/setup_wizard/presentation/pages/setup_wizard_page_test.dart
git commit -m "feat(setup): match wizard ocean brightness to the splash"
```

---

### Task 6: Whole-project verification

**Files:**
- Modify: none expected (fix anything these checks surface).

**Interfaces:**
- Consumes: all previous tasks. Produces: a branch that passes the repo's pre-push gate.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: `0 changed` (if files changed, inspect, re-run touched tests, and commit as `style: format`).

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` — run it bare (no pipes/filters); infos count as failures.

- [ ] **Step 3: Run the affected test suites together**

Run: `flutter test test/core/presentation/ test/features/settings/presentation/providers/settings_notifier_real_test.dart test/features/setup_wizard/`
Expected: all PASS.

- [ ] **Step 4: Run the full unit test suite**

Run: `flutter test`
Expected: PASS. Known flake: backup tests can fail under the full suite only — if a backup test fails, rerun that file alone before assuming this feature broke it.

- [ ] **Step 5: Commit any stragglers**

Only if Steps 1-4 produced fixes:

```bash
git add -u
git commit -m "chore: verification fixes for dark deep splash"
```
