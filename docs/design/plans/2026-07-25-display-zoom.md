# Display Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an app-wide zoom control (70%-140%) that scales every logical pixel like browser zoom, so users can trade visual size for information density.

**Architecture:** A single `Transform.scale` at the app root, paired with a `MediaQuery` whose `size`, insets, and `devicePixelRatio` are adjusted by the same factor. Because `MediaQuery` is inherited, every existing widget - including responsive breakpoints and custom-painted charts - scales with zero per-widget changes. The zoom value lives in a standalone `StateNotifier` seeded synchronously from `SharedPreferences`.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` / `StateNotifierProvider`), `shared_preferences`, Flutter `gen-l10n` ARB localization, Swift + AppKit for the macOS menu.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-25-display-zoom-design.md`
- Zoom range is exactly 70%-140% in 5% steps: `min = 0.70`, `max = 1.40`, `step = 0.05`, `defaultValue = 1.0`, `divisions = 14`.
- `displayZoom` must NOT be added to `AppSettings` or to `sync_data_serializer.dart`. It is device-local only.
- SharedPreferences key is exactly `display_zoom`, declared as a constant on the existing `SettingsKeys` class.
- Provider naming follows CLAUDE.md: `<noun>NotifierProvider` for mutable state.
- No emojis in code, comments, or documentation.
- Every user-facing string goes through `context.l10n`. New ARB keys must be added to `app_en.arb` AND translated into all 10 non-en locales (`es, fr, de, it, nl, pt, ar, he, hu, zh`), followed by an l10n regen.
- `dart format .` must produce no changes before any commit.
- `flutter analyze` must be clean across the whole project (infos are treated as failures in CI).
- No golden tests for this feature.
- Work happens in the worktree `.claude/worktrees/display-zoom` on branch `worktree-display-zoom`. Use worktree-absolute paths for all file operations.

---

### Task 1: Zoom constants and clamping

The pure-logic foundation. Everything else depends on these constants, and the clamp is the guard that stops a corrupt preference from producing a zero or NaN scale factor, which would divide by zero and blank the entire app.

**Files:**
- Create: `lib/core/theme/display_zoom.dart`
- Test: `test/core/theme/display_zoom_normalize_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class DisplayZoom` with `static const double min = 0.70`, `max = 1.40`, `step = 0.05`, `defaultValue = 1.0`, `static const int divisions = 14`, and `static double normalize(double value)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/display_zoom_normalize_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

void main() {
  group('DisplayZoom constants', () {
    test('range and step describe 14 slider divisions', () {
      expect(DisplayZoom.min, 0.70);
      expect(DisplayZoom.max, 1.40);
      expect(DisplayZoom.step, 0.05);
      expect(DisplayZoom.defaultValue, 1.0);
      expect(
        ((DisplayZoom.max - DisplayZoom.min) / DisplayZoom.step).round(),
        DisplayZoom.divisions,
      );
    });
  });

  group('DisplayZoom.normalize', () {
    test('returns in-range values unchanged', () {
      expect(DisplayZoom.normalize(0.85), 0.85);
      expect(DisplayZoom.normalize(DisplayZoom.min), DisplayZoom.min);
      expect(DisplayZoom.normalize(DisplayZoom.max), DisplayZoom.max);
    });

    test('clamps values below the minimum', () {
      expect(DisplayZoom.normalize(0.0), DisplayZoom.min);
      expect(DisplayZoom.normalize(-1.0), DisplayZoom.min);
    });

    test('clamps values above the maximum', () {
      expect(DisplayZoom.normalize(9.9), DisplayZoom.max);
    });

    test('falls back to the default for non-finite values', () {
      expect(DisplayZoom.normalize(double.nan), DisplayZoom.defaultValue);
      expect(DisplayZoom.normalize(double.infinity), DisplayZoom.defaultValue);
      expect(
        DisplayZoom.normalize(double.negativeInfinity),
        DisplayZoom.defaultValue,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/display_zoom_normalize_test.dart`
Expected: FAIL - `Error: Couldn't resolve the package 'submersion/core/theme/display_zoom.dart'` or "Undefined name 'DisplayZoom'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/theme/display_zoom.dart`:

```dart
/// App-wide display zoom constants and value clamping.
///
/// Zoom is a pure scale factor: 1.0 is the design size, values below 1.0 fit
/// more content on screen, values above 1.0 make everything larger.
class DisplayZoom {
  DisplayZoom._();

  /// Smallest supported zoom factor.
  static const double min = 0.70;

  /// Largest supported zoom factor.
  static const double max = 1.40;

  /// Increment used by the slider and the keyboard shortcuts.
  static const double step = 0.05;

  /// The unzoomed design size.
  static const double defaultValue = 1.0;

  /// Slider divisions across [min]..[max] at [step] granularity.
  static const int divisions = 14;

  static const int _minPercent = 70;
  static const int _maxPercent = 140;
  static const int _stepPercent = 5;

  /// Clamps a stored or computed value into range and snaps it to the nearest
  /// supported level.
  ///
  /// Clamping guards against a corrupt preference producing a zero or NaN
  /// scale, which would divide by zero in the layout and blank the app.
  ///
  /// Snapping prevents float drift: stepping down past [min] clamps to the
  /// floor and discards the accumulated error, so stepping back up lands on
  /// 1.0000000000000002 -- displayed as "100%" but not `== 1.0`. Snapping runs
  /// in integer-percent space so it cannot itself accumulate error.
  static double normalize(double value) {
    if (!value.isFinite) return defaultValue;
    final percent = (value * 100).round().clamp(_minPercent, _maxPercent);
    final snapped = (percent / _stepPercent).round() * _stepPercent;
    return snapped / 100;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/display_zoom_normalize_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/core/theme/display_zoom.dart test/core/theme/display_zoom_normalize_test.dart
git commit -m "feat(zoom): add display zoom constants and value clamping"
```

---

### Task 2: DisplayZoomScope widget

The widget that does the actual scaling. It is deliberately free of Riverpod and settings dependencies so it can be tested in isolation.

**Files:**
- Modify: `lib/core/theme/display_zoom.dart` (append the widget)
- Test: `test/core/theme/display_zoom_scope_test.dart`
- Test: `test/core/theme/display_zoom_hit_test.dart`

**Interfaces:**
- Consumes: `DisplayZoom.defaultValue` from Task 1.
- Produces: `class DisplayZoomScope extends StatelessWidget` with `const DisplayZoomScope({super.key, required double zoom, required Widget child})`.

- [ ] **Step 1: Write the failing scope test**

Create `test/core/theme/display_zoom_scope_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

Widget _harness({required double zoom, required Widget child}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(
        size: Size(1000, 800),
        padding: EdgeInsets.only(top: 40),
        viewPadding: EdgeInsets.only(top: 40),
        viewInsets: EdgeInsets.only(bottom: 200),
        devicePixelRatio: 2.0,
      ),
      child: DisplayZoomScope(zoom: zoom, child: child),
    ),
  );
}

void main() {
  testWidgets('is a no-op at the default zoom', (tester) async {
    await tester.pumpWidget(
      _harness(
        zoom: DisplayZoom.defaultValue,
        child: const SizedBox(key: Key('child')),
      ),
    );

    expect(find.byKey(const Key('child')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DisplayZoomScope),
        matching: find.byType(Transform),
      ),
      findsNothing,
      reason: 'no transform layer should be added at 100%',
    );
  });

  testWidgets('divides logical size and insets by the zoom factor', (
    tester,
  ) async {
    late MediaQueryData inner;

    await tester.pumpWidget(
      _harness(
        zoom: 0.8,
        child: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(inner.size.width, moreOrLessEquals(1250));
    expect(inner.size.height, moreOrLessEquals(1000));
    expect(inner.padding.top, moreOrLessEquals(50));
    expect(inner.viewPadding.top, moreOrLessEquals(50));
    expect(inner.viewInsets.bottom, moreOrLessEquals(250));
  });

  testWidgets('multiplies devicePixelRatio by the zoom factor', (tester) async {
    late MediaQueryData inner;

    await tester.pumpWidget(
      _harness(
        zoom: 0.8,
        child: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(inner.devicePixelRatio, moreOrLessEquals(1.6));
  });

  testWidgets('shrinks the logical viewport when zooming in', (tester) async {
    late MediaQueryData inner;

    await tester.pumpWidget(
      _harness(
        zoom: 1.25,
        child: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(inner.size.width, moreOrLessEquals(800));
  });
}
```

`moreOrLessEquals` is required rather than `equals`: 0.8 is not exactly representable as a double, so `1000 / 0.8` can land one ULP away from 1250.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/display_zoom_scope_test.dart`
Expected: FAIL with "Undefined name 'DisplayZoomScope'".

- [ ] **Step 3: Write minimal implementation**

Append to `lib/core/theme/display_zoom.dart`, and add `import 'package:flutter/material.dart';` at the top of the file:

```dart
/// Applies an app-wide zoom factor to everything below it.
///
/// Lays the child out in a logical space divided by [zoom], then scales that
/// space back up by [zoom] to fill the physical area. The result is true
/// browser-style zoom: text, icons, spacing, and custom painters all change
/// size together, and because [MediaQuery] is inherited, responsive
/// breakpoints below this widget see the zoomed logical width.
class DisplayZoomScope extends StatelessWidget {
  const DisplayZoomScope({super.key, required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Exact identity at the default so users who never touch the setting get
    // the same widget tree as before, with no extra transform layer.
    if (zoom == DisplayZoom.defaultValue) return child;

    final mq = MediaQuery.of(context);
    final logical = mq.size / zoom;

    return MediaQuery(
      data: mq.copyWith(
        size: logical,
        // Insets are expressed in the outer coordinate space. Without dividing
        // them, content creeps under the notch and behind the keyboard.
        padding: mq.padding / zoom,
        viewPadding: mq.viewPadding / zoom,
        viewInsets: mq.viewInsets / zoom,
        // ImageConfiguration consults this to select asset resolution.
        devicePixelRatio: mq.devicePixelRatio * zoom,
      ),
      child: Transform.scale(
        scale: zoom,
        alignment: Alignment.topLeft,
        // OverflowBox, not SizedBox: MaterialApp.builder passes TIGHT
        // constraints equal to the physical window, which would force a
        // SizedBox back to the physical size and paint only zoom-times the
        // window.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/display_zoom_scope_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the failing hit test**

This is the highest-value test in the plan. A root transform is exactly the kind of change where everything renders perfectly and nothing responds to taps, which no amount of visual review would catch.

Create `test/core/theme/display_zoom_hit_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';

void main() {
  for (final zoom in const [0.7, 0.8, 1.0, 1.3, 1.4]) {
    testWidgets('forwards taps through the transform at zoom $zoom', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DisplayZoomScope(
            zoom: zoom,
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => taps++,
                  child: const Text('Tap me'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(taps, 1, reason: 'tap must register at zoom $zoom');
    });
  }
}
```

- [ ] **Step 6: Run the hit test**

Run: `flutter test test/core/theme/display_zoom_hit_test.dart`
Expected: PASS, 5 tests. `Transform` sets `transformHitTests: true` by default, so this should pass without further implementation work. If it fails, the transform is misconfigured and must be fixed before continuing.

- [ ] **Step 7: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/core/theme/display_zoom.dart test/core/theme/display_zoom_scope_test.dart test/core/theme/display_zoom_hit_test.dart
git commit -m "feat(zoom): add DisplayZoomScope for app-wide true zoom"
```

---

### Task 3: DisplayZoomNotifier and provider

Zoom is device-local and never per-diver, so it does not live on `AppSettings`. `SettingsNotifier._initializeAndLoad()` awaits a database round-trip to resolve the diver ID before it reads `SharedPreferences`, so an `AppSettings` field would render the first frames at 100% and then pop to the stored value. Seeding a standalone notifier synchronously from the already-injected `SharedPreferences` makes that flash impossible.

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (add one key to `SettingsKeys`, near the other device-local keys around line 54)
- Create: `lib/features/settings/presentation/providers/display_zoom_provider.dart`
- Test: `test/features/settings/display_zoom_provider_test.dart`

**Interfaces:**
- Consumes: `DisplayZoom.normalize`, `DisplayZoom.defaultValue`, `DisplayZoom.step` from Task 1; `sharedPreferencesProvider` from `settings_providers.dart`.
- Produces:
  - `SettingsKeys.displayZoom` == `'display_zoom'`
  - `class DisplayZoomNotifier extends StateNotifier<double>` with `Future<void> setZoom(double value)`, `Future<void> stepBy(int direction)`, `Future<void> reset()`
  - `final displayZoomNotifierProvider = StateNotifierProvider<DisplayZoomNotifier, double>(...)`

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/display_zoom_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to 100% when nothing is stored', () async {
    final container = await _container({});
    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });

  test('reads the stored value synchronously on first read', () async {
    final container = await _container({'display_zoom': 0.85});
    expect(container.read(displayZoomNotifierProvider), 0.85);
  });

  test('clamps a corrupt stored value', () async {
    final container = await _container({'display_zoom': 0.0});
    expect(container.read(displayZoomNotifierProvider), DisplayZoom.min);
  });

  test('set persists the clamped value', () async {
    final container = await _container({});
    await container.read(displayZoomNotifierProvider.notifier).set(9.9);

    expect(container.read(displayZoomNotifierProvider), DisplayZoom.max);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('display_zoom'), DisplayZoom.max);
  });

  test('stepBy walks the ladder in both directions', () async {
    final container = await _container({'display_zoom': 1.0});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    await notifier.stepBy(1);
    expect(container.read(displayZoomNotifierProvider), moreOrLessEquals(1.05));

    await notifier.stepBy(-1);
    await notifier.stepBy(-1);
    expect(container.read(displayZoomNotifierProvider), moreOrLessEquals(0.95));
  });

  test('stepBy saturates at the bounds', () async {
    final container = await _container({'display_zoom': DisplayZoom.max});
    final notifier = container.read(displayZoomNotifierProvider.notifier);

    await notifier.stepBy(1);
    expect(container.read(displayZoomNotifierProvider), DisplayZoom.max);
  });

  test('reset returns to the default', () async {
    final container = await _container({'display_zoom': 0.75});
    await container.read(displayZoomNotifierProvider.notifier).reset();
    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/display_zoom_provider_test.dart`
Expected: FAIL - cannot resolve `display_zoom_provider.dart`.

- [ ] **Step 3: Add the preference key**

In `lib/features/settings/presentation/providers/settings_providers.dart`, inside `class SettingsKeys`, add alongside the other device-local keys (near `themeMode` around line 54):

```dart
  static const String displayZoom = 'display_zoom';
```

- [ ] **Step 4: Write the notifier**

Create `lib/features/settings/presentation/providers/display_zoom_provider.dart`:

Note: `StateNotifier` and `StateNotifierProvider` are NOT exported by
`package:flutter_riverpod/flutter_riverpod.dart` under Riverpod 3.1 - they
moved to `flutter_riverpod/legacy.dart`. Import the project barrel
`package:submersion/core/providers/provider.dart`, which re-exports both, as
every other provider file in this codebase does.

Also note the method is `setZoom`, not `set`: `set` is a built-in identifier
and shadows awkwardly, and `setZoom` matches the existing `setThemeMode` /
`setLocale` naming on `SettingsNotifier`.

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// App-wide display zoom, stored per device.
///
/// Deliberately kept off [AppSettings]: zoom is device-local rather than
/// per-diver, and SettingsNotifier awaits a database round-trip before it
/// reads SharedPreferences, which would make the first frames render at 100%
/// before snapping to the stored value. Seeding from SharedPreferences in the
/// constructor makes the correct zoom available on frame one.
class DisplayZoomNotifier extends StateNotifier<double> {
  DisplayZoomNotifier(this._prefs)
    : super(
        DisplayZoom.normalize(
          _prefs.getDouble(SettingsKeys.displayZoom) ??
              DisplayZoom.defaultValue,
        ),
      );

  final SharedPreferences _prefs;

  Future<void> set(double value) async {
    final clamped = DisplayZoom.normalize(value);
    if (clamped == state) return;
    state = clamped;
    await _prefs.setDouble(SettingsKeys.displayZoom, clamped);
  }

  /// Moves one [DisplayZoom.step] in [direction] (+1 larger, -1 smaller).
  Future<void> stepBy(int direction) =>
      set(state + direction * DisplayZoom.step);

  Future<void> reset() => set(DisplayZoom.defaultValue);
}

final displayZoomNotifierProvider =
    StateNotifierProvider<DisplayZoomNotifier, double>((ref) {
      return DisplayZoomNotifier(ref.watch(sharedPreferencesProvider));
    });
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/settings/display_zoom_provider_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/presentation/providers/display_zoom_provider.dart lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/display_zoom_provider_test.dart
git commit -m "feat(zoom): add device-local display zoom provider"
```

---

### Task 4: Wire zoom into the app root

**Files:**
- Modify: `lib/app.dart` (the `builder` callback, around line 361)
- Test: `test/shared/widgets/display_zoom_breakpoints_test.dart`

**Interfaces:**
- Consumes: `DisplayZoomScope` (Task 2), `displayZoomNotifierProvider` (Task 3).
- Produces: zoom applied to the whole app; `ResponsiveBreakpoints` now evaluates against the zoomed logical width.

- [ ] **Step 1: Write the failing breakpoint test**

This test encodes a design decision rather than an incidental behavior. Floating breakpoints are what falls out naturally, and without this test a future maintainer debugging "why did my iPad flip to split view" could quietly pin them and silently remove the feature's main benefit.

Create `test/shared/widgets/display_zoom_breakpoints_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

Future<bool> _isMasterDetailAt(WidgetTester tester, double zoom) async {
  late bool result;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1000, 800)),
        child: DisplayZoomScope(
          zoom: zoom,
          child: Builder(
            builder: (context) {
              result = ResponsiveBreakpoints.isMasterDetail(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );

  return result;
}

void main() {
  testWidgets('a 1000pt viewport is not master-detail at 100%', (tester) async {
    expect(await _isMasterDetailAt(tester, DisplayZoom.defaultValue), isFalse);
  });

  testWidgets('zooming out unlocks master-detail on the same viewport', (
    tester,
  ) async {
    // 1000 / 0.85 = 1176pt, past the 1100pt master-detail breakpoint.
    expect(await _isMasterDetailAt(tester, 0.85), isTrue);
  });

  testWidgets('zooming in can drop below the desktop breakpoint', (
    tester,
  ) async {
    // 1000 / 1.4 = 714pt, below the 800pt desktop breakpoint.
    late bool isMobile;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1000, 800)),
          child: DisplayZoomScope(
            zoom: DisplayZoom.max,
            child: Builder(
              builder: (context) {
                isMobile = ResponsiveBreakpoints.isMobile(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(isMobile, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/shared/widgets/display_zoom_breakpoints_test.dart`
Expected: PASS, 3 tests. This test exercises Task 2's widget directly, so it should pass immediately - it exists to lock the behavior in, not to drive new code.

- [ ] **Step 3: Wire the scope into app.dart**

In `lib/app.dart`, add the imports:

```dart
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
```

Replace the `builder` callback (around line 361) with:

```dart
      builder: (context, child) {
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        // Block all interaction while a database restore runs, so no data page
        // can rebuild against the transient null database mid-restore. Kept
        // outside the zoom scope so the barrier stays a full-screen, unscaled
        // overlay.
        return RestoreBarrier(
          child: Consumer(
            builder: (context, ref, _) {
              // Watched here rather than in build() so dragging the zoom
              // slider rebuilds only this subtree, not all of MaterialApp.
              final zoom = ref.watch(displayZoomNotifierProvider);
              return DisplayZoomScope(zoom: zoom, child: child!);
            },
          ),
        );
      },
```

- [ ] **Step 4: Verify the app-level tests still pass**

Run: `flutter test test/l10n/localization_test.dart test/core/presentation/pages/startup_page_test.dart`
Expected: PASS. `test/l10n/localization_test.dart` pumps `SubmersionApp` and already overrides `sharedPreferencesProvider` (line 218), which is the only dependency the new provider adds. If any test fails with a `sharedPreferencesProvider` `UnimplementedError`, add that override to the failing test's `ProviderScope`.

- [ ] **Step 5: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/app.dart test/shared/widgets/display_zoom_breakpoints_test.dart
git commit -m "feat(zoom): apply display zoom at the app root"
```

---

### Task 5: Keyboard shortcuts

**Files:**
- Create: `lib/core/theme/display_zoom_shortcuts.dart`
- Modify: `lib/app.dart` (the `builder` callback from Task 4)
- Test: `test/core/theme/display_zoom_shortcuts_test.dart`

**Interfaces:**
- Consumes: `displayZoomNotifierProvider` (Task 3).
- Produces: `Map<ShortcutActivator, VoidCallback> displayZoomShortcuts({required VoidCallback onZoomIn, required VoidCallback onZoomOut, required VoidCallback onReset, required bool useMetaModifier})`.

The function takes plain callbacks rather than the notifier so that `lib/core/` gains no dependency on `lib/features/`, and so the bindings can be tested without Riverpod.

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/display_zoom_shortcuts_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/display_zoom_shortcuts.dart';

void main() {
  late List<String> fired;

  Widget harness({required bool useMetaModifier}) {
    return MaterialApp(
      home: CallbackShortcuts(
        bindings: displayZoomShortcuts(
          onZoomIn: () => fired.add('in'),
          onZoomOut: () => fired.add('out'),
          onReset: () => fired.add('reset'),
          useMetaModifier: useMetaModifier,
        ),
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    );
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  setUp(() => fired = []);

  testWidgets('control shortcuts fire on non-Apple platforms', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: false));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.equal);
    await press(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.minus);
    await press(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.digit0);

    expect(fired, ['in', 'out', 'reset']);
  });

  testWidgets('numpad plus and minus are also bound', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: false));
    await tester.pump();

    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.numpadAdd,
    );
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.numpadSubtract,
    );

    expect(fired, ['in', 'out']);
  });

  testWidgets('meta shortcuts fire on Apple platforms', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: true));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.equal);

    expect(fired, ['in']);
  });

  testWidgets('the wrong modifier does not fire', (tester) async {
    await tester.pumpWidget(harness(useMetaModifier: false));
    await tester.pump();

    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.equal);

    expect(fired, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/display_zoom_shortcuts_test.dart`
Expected: FAIL - cannot resolve `display_zoom_shortcuts.dart`.

- [ ] **Step 3: Write the bindings**

Create `lib/core/theme/display_zoom_shortcuts.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard bindings for app-wide display zoom.
///
/// Takes callbacks rather than a notifier so this file stays free of feature
/// and Riverpod dependencies.
///
/// On macOS these bindings are normally never reached: once the View menu
/// items carry key equivalents, AppKit consumes the chords before the Flutter
/// engine sees them. They remain registered as the Windows and Linux path.
Map<ShortcutActivator, VoidCallback> displayZoomShortcuts({
  required VoidCallback onZoomIn,
  required VoidCallback onZoomOut,
  required VoidCallback onReset,
  required bool useMetaModifier,
}) {
  SingleActivator activator(LogicalKeyboardKey key) => SingleActivator(
    key,
    meta: useMetaModifier,
    control: !useMetaModifier,
  );

  return {
    // "equal" is the unshifted key users actually press for zoom in.
    activator(LogicalKeyboardKey.equal): onZoomIn,
    activator(LogicalKeyboardKey.numpadAdd): onZoomIn,
    activator(LogicalKeyboardKey.minus): onZoomOut,
    activator(LogicalKeyboardKey.numpadSubtract): onZoomOut,
    activator(LogicalKeyboardKey.digit0): onReset,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/display_zoom_shortcuts_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Wire the shortcuts into app.dart**

Add to `lib/app.dart` imports:

```dart
import 'package:flutter/foundation.dart';
import 'package:submersion/core/theme/display_zoom_shortcuts.dart';
```

Replace the `Consumer` body added in Task 4 with:

```dart
            builder: (context, ref, _) {
              // Watched here rather than in build() so dragging the zoom
              // slider rebuilds only this subtree, not all of MaterialApp.
              final zoom = ref.watch(displayZoomNotifierProvider);
              final notifier = ref.read(displayZoomNotifierProvider.notifier);
              final useMeta =
                  defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.iOS;

              return CallbackShortcuts(
                bindings: displayZoomShortcuts(
                  onZoomIn: () => notifier.stepBy(1),
                  onZoomOut: () => notifier.stepBy(-1),
                  onReset: notifier.reset,
                  useMetaModifier: useMeta,
                ),
                // CallbackShortcuts only fires for keystrokes inside its
                // focused subtree, and nothing has focus on desktop
                // cold-start, so the shortcuts would otherwise be dead until
                // the user clicks something.
                child: Focus(
                  autofocus: true,
                  child: DisplayZoomScope(zoom: zoom, child: child!),
                ),
              );
            },
```

- [ ] **Step 6: Verify app-level tests still pass**

Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS. The added `Focus(autofocus: true)` claims focus at app start; if any existing test asserts on initial focus it will surface here.

- [ ] **Step 7: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/core/theme/display_zoom_shortcuts.dart lib/app.dart test/core/theme/display_zoom_shortcuts_test.dart
git commit -m "feat(zoom): add zoom in/out/reset keyboard shortcuts"
```

---

### Task 6: Appearance page control

The control is extracted into its own widget rather than inlined into `AppearancePage`. It only needs `displayZoomNotifierProvider` and localization, so it can be tested without the `settingsProvider` mock scaffolding the full page requires.

**Files:**
- Create: `lib/features/settings/presentation/widgets/display_zoom_settings_tile.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart` (General section, between the theme selector at line 63 and the Language tile at line 65)
- Test: `test/features/settings/presentation/display_zoom_settings_tile_test.dart`

**Interfaces:**
- Consumes: `DisplayZoom` constants (Task 1), `displayZoomNotifierProvider` (Task 3).
- Produces: `class DisplayZoomSettingsTile extends ConsumerWidget` with `const DisplayZoomSettingsTile({super.key})`.

- [ ] **Step 1: Add the English ARB keys**

In `lib/l10n/arb/app_en.arb`, add:

```json
  "settings_appearance_displaySize": "Display size",
  "@settings_appearance_displaySize": {
    "description": "Title of the app-wide display zoom control in Appearance settings"
  },
  "settings_appearance_displaySize_value": "{percent}%",
  "@settings_appearance_displaySize_value": {
    "description": "Current display zoom level shown as a percentage",
    "placeholders": {
      "percent": {
        "type": "int"
      }
    }
  },
  "settings_appearance_displaySize_reset": "Reset",
  "@settings_appearance_displaySize_reset": {
    "description": "Button that returns the display zoom to 100 percent"
  },
  "settings_appearance_displaySize_smaller": "Smaller",
  "@settings_appearance_displaySize_smaller": {
    "description": "Label at the low end of the display zoom slider"
  },
  "settings_appearance_displaySize_larger": "Larger",
  "@settings_appearance_displaySize_larger": {
    "description": "Label at the high end of the display zoom slider"
  },
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: succeeds. Warnings about the 10 non-en locales missing these keys are expected and are resolved in Task 7.

- [ ] **Step 3: Write the failing widget test**

Create `test/features/settings/presentation/display_zoom_settings_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/display_zoom_settings_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<ProviderContainer> _pumpTile(
  WidgetTester tester,
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: DisplayZoomSettingsTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the current zoom as a percentage', (tester) async {
    await _pumpTile(tester, {'display_zoom': 0.85});

    expect(find.text('Display size'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('hides the reset action at 100%', (tester) async {
    await _pumpTile(tester, {});

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('reset returns the zoom to 100%', (tester) async {
    final container = await _pumpTile(tester, {'display_zoom': 0.75});

    expect(find.text('Reset'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });

  testWidgets('the slider is configured for the supported range', (
    tester,
  ) async {
    await _pumpTile(tester, {});

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, DisplayZoom.min);
    expect(slider.max, DisplayZoom.max);
    expect(slider.divisions, DisplayZoom.divisions);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/display_zoom_settings_tile_test.dart`
Expected: FAIL - cannot resolve `display_zoom_settings_tile.dart`.

- [ ] **Step 5: Write the widget**

Create `lib/features/settings/presentation/widgets/display_zoom_settings_tile.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-wide display zoom control.
///
/// No preview widget: zoom is applied at the app root, so this settings page
/// scales as the slider moves and is itself the live preview.
class DisplayZoomSettingsTile extends ConsumerWidget {
  const DisplayZoomSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(displayZoomNotifierProvider);
    final notifier = ref.read(displayZoomNotifierProvider.notifier);
    final l10n = context.l10n;
    final percent = (zoom * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text(l10n.settings_appearance_displaySize),
          subtitle: Text(l10n.settings_appearance_displaySize_value(percent)),
          trailing: zoom == DisplayZoom.defaultValue
              ? null
              : TextButton(
                  onPressed: notifier.reset,
                  child: Text(l10n.settings_appearance_displaySize_reset),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                l10n.settings_appearance_displaySize_smaller,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Expanded(
                child: Slider(
                  value: zoom,
                  min: DisplayZoom.min,
                  max: DisplayZoom.max,
                  divisions: DisplayZoom.divisions,
                  label: l10n.settings_appearance_displaySize_value(percent),
                  onChanged: notifier.setZoom,
                ),
              ),
              Text(
                l10n.settings_appearance_displaySize_larger,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/settings/presentation/display_zoom_settings_tile_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 7: Embed the tile in the Appearance page**

In `lib/features/settings/presentation/pages/appearance_page.dart`, add the import:

```dart
import 'package:submersion/features/settings/presentation/widgets/display_zoom_settings_tile.dart';
```

Then, between `_buildThemeSelector(...)` and the `Divider()` preceding the Language `ListTile` (lines 63-65), insert:

```dart
          const Divider(),
          const DisplayZoomSettingsTile(),
```

- [ ] **Step 8: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/presentation/widgets/display_zoom_settings_tile.dart lib/features/settings/presentation/pages/appearance_page.dart lib/l10n/ test/features/settings/presentation/display_zoom_settings_tile_test.dart
git commit -m "feat(zoom): add display size control to Appearance settings"
```

---

### Task 7: Translate into all 10 non-en locales

**Files:**
- Modify: `lib/l10n/arb/app_es.arb`, `app_fr.arb`, `app_de.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_ar.arb`, `app_he.arb`, `app_hu.arb`, `app_zh.arb`

**Interfaces:**
- Consumes: the five keys added to `app_en.arb` in Task 6.
- Produces: no new symbols.

- [ ] **Step 1: Add translations**

Add these keys to each locale file. Only the `settings_appearance_displaySize_value` key takes a placeholder; keep `{percent}%` unchanged in every locale.

`app_es.arb`:
```json
  "settings_appearance_displaySize": "Tamaño de visualización",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Restablecer",
  "settings_appearance_displaySize_smaller": "Más pequeño",
  "settings_appearance_displaySize_larger": "Más grande",
```

`app_fr.arb`:
```json
  "settings_appearance_displaySize": "Taille d'affichage",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Réinitialiser",
  "settings_appearance_displaySize_smaller": "Plus petit",
  "settings_appearance_displaySize_larger": "Plus grand",
```

`app_de.arb`:
```json
  "settings_appearance_displaySize": "Anzeigegröße",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Zurücksetzen",
  "settings_appearance_displaySize_smaller": "Kleiner",
  "settings_appearance_displaySize_larger": "Größer",
```

`app_it.arb`:
```json
  "settings_appearance_displaySize": "Dimensione di visualizzazione",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Reimposta",
  "settings_appearance_displaySize_smaller": "Più piccolo",
  "settings_appearance_displaySize_larger": "Più grande",
```

`app_nl.arb`:
```json
  "settings_appearance_displaySize": "Weergavegrootte",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Herstellen",
  "settings_appearance_displaySize_smaller": "Kleiner",
  "settings_appearance_displaySize_larger": "Groter",
```

`app_pt.arb`:
```json
  "settings_appearance_displaySize": "Tamanho de exibição",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Redefinir",
  "settings_appearance_displaySize_smaller": "Menor",
  "settings_appearance_displaySize_larger": "Maior",
```

`app_ar.arb`:
```json
  "settings_appearance_displaySize": "حجم العرض",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "إعادة تعيين",
  "settings_appearance_displaySize_smaller": "أصغر",
  "settings_appearance_displaySize_larger": "أكبر",
```

`app_he.arb`:
```json
  "settings_appearance_displaySize": "גודל התצוגה",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "איפוס",
  "settings_appearance_displaySize_smaller": "קטן יותר",
  "settings_appearance_displaySize_larger": "גדול יותר",
```

`app_hu.arb`:
```json
  "settings_appearance_displaySize": "Megjelenítési méret",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "Visszaállítás",
  "settings_appearance_displaySize_smaller": "Kisebb",
  "settings_appearance_displaySize_larger": "Nagyobb",
```

`app_zh.arb`:
```json
  "settings_appearance_displaySize": "显示大小",
  "settings_appearance_displaySize_value": "{percent}%",
  "settings_appearance_displaySize_reset": "重置",
  "settings_appearance_displaySize_smaller": "更小",
  "settings_appearance_displaySize_larger": "更大",
```

- [ ] **Step 2: Regenerate and verify no untranslated warnings**

Run: `flutter gen-l10n`
Expected: succeeds with no warnings naming `settings_appearance_displaySize*`.

- [ ] **Step 3: Run the localization suite**

Run: `flutter test test/l10n/`
Expected: PASS.

- [ ] **Step 4: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib/l10n/
git commit -m "i18n(zoom): translate display size strings into all locales"
```

---

### Task 8: macOS View menu

**Files:**
- Modify: `macos/Runner/Base.lproj/MainMenu.xib` (View submenu `HyV-fh-RgO`, `<items>` block at line 298)
- Modify: `macos/Runner/AppDelegate.swift`
- Create: `lib/features/settings/presentation/providers/display_zoom_menu_channel.dart`
- Modify: `lib/app.dart` (`initState`, alongside `registerUpdateMenuChannel(ref)` at line 84)

**Interfaces:**
- Consumes: `displayZoomNotifierProvider` (Task 3).
- Produces: `void registerDisplayZoomMenuChannel(WidgetRef ref)`, and a `MethodChannel('app.submersion/display')` accepting the methods `zoomIn`, `zoomOut`, and `actualSize`.

This task has no automated test. AppKit menu wiring cannot be exercised from `flutter test`, so it ends with a manual verification step instead.

- [ ] **Step 1: Add the menu items to the xib**

In `macos/Runner/Base.lproj/MainMenu.xib`, replace the View submenu `<items>` block (lines 298-305) with:

```xml
                        <items>
                            <menuItem title="Zoom In" keyEquivalent="+" id="Zmi-In-001">
                                <modifierMask key="keyEquivalentModifierMask" command="YES"/>
                                <connections>
                                    <action selector="zoomIn:" target="Voe-Tx-rLC" id="Zmi-In-a01"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Zoom In" keyEquivalent="=" hidden="YES" id="Zmi-In-002">
                                <modifierMask key="keyEquivalentModifierMask" command="YES"/>
                                <connections>
                                    <action selector="zoomIn:" target="Voe-Tx-rLC" id="Zmi-In-a02"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Zoom Out" keyEquivalent="-" id="Zmo-Ut-003">
                                <modifierMask key="keyEquivalentModifierMask" command="YES"/>
                                <connections>
                                    <action selector="zoomOut:" target="Voe-Tx-rLC" id="Zmo-Ut-a03"/>
                                </connections>
                            </menuItem>
                            <menuItem title="Actual Size" keyEquivalent="0" id="Act-Sz-004">
                                <modifierMask key="keyEquivalentModifierMask" command="YES"/>
                                <connections>
                                    <action selector="actualSize:" target="Voe-Tx-rLC" id="Act-Sz-a04"/>
                                </connections>
                            </menuItem>
                            <menuItem isSeparatorItem="YES" id="Zsp-Ar-005"/>
                            <menuItem title="Enter Full Screen" keyEquivalent="f" id="4J7-dP-txa">
                                <modifierMask key="keyEquivalentModifierMask" control="YES" command="YES"/>
                                <connections>
                                    <action selector="toggleFullScreen:" target="-1" id="dU3-MA-1Rq"/>
                                </connections>
                            </menuItem>
                        </items>
```

`Voe-Tx-rLC` is the existing AppDelegate object already targeted by the `checkForUpdates:` action at line 39. The second "Zoom In" item is hidden and exists only so Cmd+= works: users press the unshifted `=` key, but every macOS app displays the shortcut as Cmd++, which requires Shift. Safari and Chrome ship the same duplicate.

- [ ] **Step 2: Add the Swift actions**

In `macos/Runner/AppDelegate.swift`, add an instance variable next to `updateChannel` (line 14):

```swift
  private var displayChannel: FlutterMethodChannel?
```

Inside `applicationDidFinishLaunching`, immediately after the `updateChannel` assignment (lines 44-47):

```swift
      displayChannel = FlutterMethodChannel(
        name: "app.submersion/display",
        binaryMessenger: messenger
      )
```

And after `checkForUpdates` (line 56):

```swift
  @IBAction func zoomIn(_ sender: Any) {
    displayChannel?.invokeMethod("zoomIn", arguments: nil)
  }

  @IBAction func zoomOut(_ sender: Any) {
    displayChannel?.invokeMethod("zoomOut", arguments: nil)
  }

  @IBAction func actualSize(_ sender: Any) {
    displayChannel?.invokeMethod("actualSize", arguments: nil)
  }
```

- [ ] **Step 3: Add the Dart channel handler**

Create `lib/features/settings/presentation/providers/display_zoom_menu_channel.dart`, mirroring `update_menu_channel.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';

const _channel = MethodChannel('app.submersion/display');

/// Registers a method channel handler so the macOS View menu can drive the
/// app-wide display zoom.
void registerDisplayZoomMenuChannel(WidgetRef ref) {
  _channel.setMethodCallHandler((call) async {
    final notifier = ref.read(displayZoomNotifierProvider.notifier);
    switch (call.method) {
      case 'zoomIn':
        await notifier.stepBy(1);
      case 'zoomOut':
        await notifier.stepBy(-1);
      case 'actualSize':
        await notifier.reset();
    }
  });
}
```

- [ ] **Step 4: Register the channel at startup**

In `lib/app.dart`, add the import:

```dart
import 'package:submersion/features/settings/presentation/providers/display_zoom_menu_channel.dart';
```

In `initState`, directly after `registerUpdateMenuChannel(ref);` (line 84):

```dart
    registerDisplayZoomMenuChannel(ref);
```

- [ ] **Step 5: Verify the build and the test suite**

```bash
dart format .
flutter analyze
flutter test
```
Expected: analyze clean, full suite passes.

- [ ] **Step 6: Manual macOS verification**

Run: `flutter run -d macos`

Check each of these:

1. View menu shows Zoom In, Zoom Out, Actual Size above a separator, then Enter Full Screen.
2. Cmd+Shift+= (displayed as Cmd++) zooms in.
3. **Cmd+= (unshifted) zooms in.** If this does nothing, the hidden duplicate is not receiving key equivalents. Fallback: delete the hidden item `Zmi-In-002` and change the visible item `Zmi-In-001` from `keyEquivalent="+"` to `keyEquivalent="="`. The menu will then display Cmd+= instead of Cmd++, which is a cosmetic regression but functionally correct.
4. Cmd+- zooms out; Cmd+0 returns to 100%.
5. The Appearance page slider reflects changes made from the menu.
6. Quit and relaunch: the zoom level persists.

- [ ] **Step 7: Commit**

```bash
git add macos/Runner/Base.lproj/MainMenu.xib macos/Runner/AppDelegate.swift lib/features/settings/presentation/providers/display_zoom_menu_channel.dart lib/app.dart
git commit -m "feat(zoom): add macOS View menu zoom items"
```

---

### Task 9: Full verification

**Files:** none modified unless a check fails.

**Interfaces:**
- Consumes: everything from Tasks 1-8.
- Produces: a branch ready for review.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: "0 changed".

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!". Never pipe this through `tail` or `head` - it masks the exit status.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass.

This step is mandatory and cannot be replaced by running only the new test files. Adding an app-level provider dependency can break widget tests that pump `SubmersionApp` without a matching `ProviderScope` override, and `flutter analyze` does not catch that class of failure.

- [ ] **Step 4: Confirm zoom stayed out of sync**

Run: `grep -rn "displayZoom\|display_zoom" lib/core/services/sync/`
Expected: no matches. Zoom is device-local by design; a match means it leaked into the sync payload.

- [ ] **Step 5: Verify AppSettings was not modified**

Run: `git diff origin/main --stat -- lib/features/settings/presentation/providers/settings_providers.dart`
Expected: a single-line addition (the `SettingsKeys.displayZoom` constant). Any change to the `AppSettings` class, its `copyWith`, `_loadSettings`, or `_saveSettings` means the standalone-provider design was not followed and the startup flash is back.

- [ ] **Step 6: Manual smoke check on a second platform**

Run the app on any non-macOS target available (`flutter run -d <device>`), then:

1. Open Appearance settings and drag the Display size slider. The settings page itself should scale as you drag.
2. On desktop, narrow the window to roughly 1000pt at 100% zoom and confirm the dive list is single-pane, then zoom out to 85% and confirm the master-detail split view appears.
3. Confirm dividers, icons, and the dive profile chart all scale together rather than only the text.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| `DisplayZoom` constants and `normalize` | 1 |
| `DisplayZoomScope` with all five MediaQuery field adjustments | 2 |
| `DisplayZoomNotifier` + `displayZoomNotifierProvider` + `SettingsKeys.displayZoom` | 3 |
| `app.dart` wiring, `RestoreBarrier` ordering, `Consumer` placement | 4 |
| `CallbackShortcuts`, `Focus(autofocus: true)`, platform modifier | 5 |
| Appearance slider, no preview widget, Reset action | 6 |
| Five ARB keys in `app_en.arb` | 6 |
| Translations for all 10 non-en locales + regen | 7 |
| macOS xib items incl. hidden Cmd+= duplicate, AppDelegate, MethodChannel | 8 |
| Six spec test files | 1 (clamp), 2 (scope, hit), 3 (provider), 4 (breakpoints), 5 (shortcuts) |
| Risk 6 (consumer test breakage) | 4 Step 4, 9 Step 3 |
| Risk 5 (macOS silent failure) | 8 Step 6 |
| No golden tests | Global Constraints |

One addition beyond the spec: `test/features/settings/presentation/display_zoom_settings_tile_test.dart` (Task 6), so the new UI is covered by TDD like everything else.

**Placeholder scan:** No TBD, TODO, "handle edge cases", or "similar to Task N" entries. Every code step contains complete, compilable content.

**Type consistency:** `DisplayZoom.normalize`/`min`/`max`/`step`/`defaultValue`/`divisions`, `DisplayZoomScope({zoom, child})`, `DisplayZoomNotifier.setZoom`/`stepBy`/`reset`, `displayZoomNotifierProvider`, `displayZoomShortcuts({onZoomIn, onZoomOut, onReset, useMetaModifier})`, `registerDisplayZoomMenuChannel`, and `SettingsKeys.displayZoom` are each named identically everywhere they appear. Channel name `app.submersion/display` and its three methods match between Swift and Dart.
