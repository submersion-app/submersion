# Fullscreen Dive Profile Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fullscreen dive profile view fill the screen (#443) and add a dive-computer-style instrument bar with playback that tracks the cursor (#169), per the approved spec at `docs/superpowers/specs/2026-07-02-fullscreen-profile-redesign-design.md`.

**Architecture:** Extract the fullscreen view out of `dive_detail_page.dart` into a new `FullscreenProfilePage` that takes only a `diveId` and watches family providers. `DiveProfileChart` gains height flexibility (fills bounded parents) and a `legendLeading` slot so the close button and title share the legend row. The existing playback engine is reworked to frame-based ticking with compressed speed presets; a unified review-position provider drives the chart cursor, instrument tiles, and slider.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier/StateProvider families), fl_chart, SharedPreferences, flutter gen-l10n.

**Spec deviation (approved rationale):** The spec proposed a `showLegend: false` chart parameter with the page composing `DiveProfileLegend` externally. `DiveProfileLegend` requires `zoomLevel`/`onZoomIn`/`onZoomOut`/`onResetZoom`, which are private to `_DiveProfileChartState` (`dive_profile_chart.dart:1249-1258`). Exposing them would need a controller object. Instead the chart gains an optional `legendLeading` widget slot rendered at the start of its existing legend row — same single-row header visual, no new controller. Everything else follows the spec.

## Global Constraints

- Run `dart format .` on the WHOLE repo before every commit (CI checks the whole project).
- Run `flutter analyze` on the WHOLE project (never pipe through `tail`/`head` to gate success).
- Run specific test files, never broad directories (avoids Bash timeouts): `flutter test test/path/to/file_test.dart`.
- Every new user-visible string goes in `lib/l10n/arb/app_en.arb` AND all 10 other locale files (`app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`), then run `flutter gen-l10n`.
- No emojis in code, comments, or docs. Sound null safety. Immutability (copyWith pattern).
- Store metric internally; format for display only via `UnitFormatter` (`lib/core/utils/unit_formatter.dart`).
- Commit messages: conventional commits, NO Co-Authored-By lines.
- New widget/provider files follow existing import grouping: dart, flutter, packages, local.

---

### Task 1: Chart height flexibility (#443 root fix)

The chart plot is pinned to `SizedBox(height: 200)` regardless of parent height. Make it fill the parent when the parent provides bounded height; keep the 200px default when unbounded (inline scroll views).

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:1238-1292` (the `LayoutBuilder`/`Column` in `build`)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart` (create)

**Interfaces:**
- Consumes: existing `DiveProfileChart` public constructor (unchanged).
- Produces: layout behavior — bounded-height parent means the plot expands; unbounded means 200px. Later tasks (Task 9) rely on wrapping the chart in `Expanded` to fill the screen.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`. Reuse the settings-override pattern from the existing `dive_profile_chart_test.dart` (a `StateNotifier<AppSettings> implements SettingsNotifier` fake with `noSuchMethod`):

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _testProfile() => List.generate(
  61,
  (i) => DiveProfilePoint(timestamp: i * 10, depth: i < 30 ? i.toDouble() : (60 - i).toDouble()),
);

Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('plot fills a bounded-height parent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 800,
          height: 600,
          child: DiveProfileChart(
            profile: _testProfile(),
            diveDuration: const Duration(minutes: 10),
            maxDepth: 30,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plotHeight = tester.getSize(find.byType(LineChart).first).height;
    // Legend row takes some height; the plot must get the rest — far more
    // than the old fixed 200.
    expect(plotHeight, greaterThan(400));
  });

  testWidgets('plot keeps 200px default when height is unbounded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [
            DiveProfileChart(
              profile: _testProfile(),
              diveDuration: const Duration(minutes: 10),
              maxDepth: 30,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plotHeight = tester.getSize(find.byType(LineChart).first).height;
    expect(plotHeight, 200);
  });
}
```

Note: if `DiveProfileChart`'s constructor requires different parameter names/types for `diveDuration` (check the actual signature at `dive_profile_chart.dart:46-375` — the fullscreen call site at `dive_detail_page.dart:4942` passes `diveDuration: dive.effectiveRuntime` which is a `Duration?`), adjust the fixture accordingly. If a gas-timeline strip or another `LineChart` renders, `.first` selects the main plot; verify with `find.byType(LineChart)` count and pick the largest if needed.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`
Expected: FAIL — first test gets `200` instead of `> 400`.

- [ ] **Step 3: Make the plot sizing conditional**

In `dive_profile_chart.dart`, the `build` method returns `LayoutBuilder(builder: (context, constraints) { ... Column(...) })` (line 1238). Replace the fixed plot wrapper (lines 1262-1274):

```dart
// Before:
            RepaintBoundary(
              key: widget.exportKey,
              child: SizedBox(
                height: 200,
                child: _buildInteractiveChart(
                  context,
                  units,
                  hasTemperatureData: hasTemperatureData,
                  hasPressureData: hasPressureData,
                  hasHeartRateData: hasHeartRateData,
                ),
              ),
            ),
```

```dart
// After: fill bounded parents (fullscreen), keep 200px in scroll views.
            if (constraints.hasBoundedHeight)
              Expanded(
                child: RepaintBoundary(
                  key: widget.exportKey,
                  child: _buildInteractiveChart(
                    context,
                    units,
                    hasTemperatureData: hasTemperatureData,
                    hasPressureData: hasPressureData,
                    hasHeartRateData: hasHeartRateData,
                  ),
                ),
              )
            else
              RepaintBoundary(
                key: widget.exportKey,
                child: SizedBox(
                  height: 200,
                  child: _buildInteractiveChart(
                    context,
                    units,
                    hasTemperatureData: hasTemperatureData,
                    hasPressureData: hasPressureData,
                    hasHeartRateData: hasHeartRateData,
                  ),
                ),
              ),
```

Extract the duplicated `_buildInteractiveChart(...)` call into a local variable above the `Column` if you prefer, but keep the `RepaintBoundary` + `widget.exportKey` in exactly one place in the tree (PNG export depends on it):

```dart
        final plot = RepaintBoundary(
          key: widget.exportKey,
          child: _buildInteractiveChart(
            context,
            units,
            hasTemperatureData: hasTemperatureData,
            hasPressureData: hasPressureData,
            hasHeartRateData: hasHeartRateData,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiveProfileLegend( ... ),  // unchanged
            if (constraints.hasBoundedHeight)
              Expanded(child: plot)
            else
              SizedBox(height: 200, child: plot),
            // Zoom hint (unchanged)
            ...
          ],
        );
```

CAUTION: existing bounded-height call sites now grow. Known ones: the old fullscreen `SizedBox(height: 280/350)` (`dive_detail_page.dart:4940`) — desired, and deleted in Task 11 anyway. Check `dive_profile_panel.dart` and `overlaid_profile_chart.dart` for bounded wrappers; if their layouts change unintentionally, wrap those call sites in an explicit `SizedBox(height: 200)`-equivalent unbounded context is NOT possible — instead give them an explicit fixed height around the chart, preserving today's look.

- [ ] **Step 4: Run the new test and the existing chart tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`
Expected: PASS (both tests)

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart`
Expected: PASS (no regression; if a panel test fails on layout, apply the explicit-height fix from Step 3's caution note)

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "fix(profile): let dive profile chart fill bounded-height parents (#443)"
```

---

### Task 2: `legendLeading` slot on the chart

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (constructor params ~line 46-375; legend row at ~1249)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart` (extend)

**Interfaces:**
- Consumes: nothing new.
- Produces: `DiveProfileChart(legendLeading: Widget?)` — rendered before the legend in the same row. Task 9's page passes a close button + title here.

- [ ] **Step 1: Write the failing test**

Append to `dive_profile_chart_sizing_test.dart`:

```dart
  testWidgets('legendLeading renders in the legend row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 800,
          height: 600,
          child: DiveProfileChart(
            profile: _testProfile(),
            diveDuration: const Duration(minutes: 10),
            maxDepth: 30,
            legendLeading: const Text('LEADING-MARKER'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEADING-MARKER'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`
Expected: FAIL — compile error, `legendLeading` is not a parameter.

- [ ] **Step 3: Add the parameter and render it**

In `DiveProfileChart`'s constructor field block add:

```dart
  /// Optional widget rendered at the start of the legend row (e.g. a close
  /// button and title in the fullscreen view).
  final Widget? legendLeading;
```

and to the constructor: `this.legendLeading,`.

At the legend row (~line 1249), wrap:

```dart
// Before:
            DiveProfileLegend(
              config: legendConfig,
              ...
            ),
// After:
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.legendLeading != null) widget.legendLeading!,
                Expanded(
                  child: DiveProfileLegend(
                    config: legendConfig,
                    zoomLevel: _viewport.zoom,
                    minZoom: ProfileChartViewport.minZoom,
                    maxZoom: ProfileChartViewport.maxZoom,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onResetZoom: _resetZoom,
                    leftPadding: widget.legendLeading == null
                        ? legendLeftPadding
                        : 0,
                  ),
                ),
              ],
            ),
```

(When a leading widget is present, drop the axis-alignment `leftPadding` — the fullscreen header is left-anchored to the close button instead.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): add legendLeading slot to dive profile chart"
```

---

### Task 3: Playback engine rework (frame ticks + compressed speeds)

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/profile_playback_provider.dart`
- Modify: `lib/features/dive_log/presentation/widgets/playback_controls.dart:234-239` (speed presets)
- Test: `test/features/dive_log/presentation/providers/profile_playback_provider_test.dart` (create)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `PlaybackNotifier.speedPresets` — `static const List<double> [1, 5, 15, 30, 60, 120]`
  - `PlaybackState.playbackSpeed` default `30.0`
  - Unchanged public API: `initialize(int durationSeconds)`, `togglePlaybackMode()`, `play()`, `pause()`, `togglePlayPause()`, `stepForward()`, `stepBackward()`, `skipToStart()`, `skipToEnd()`, `seekTo(int)`, `seekToProgress(double)`, `setSpeed(double)` (now clamps 1.0-120.0)
  - Smooth ticking: a 25ms periodic timer advancing `0.025 * playbackSpeed` dive-seconds per tick (40 ticks/s makes 1 wall-second advance exactly `playbackSpeed` dive-seconds).

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/providers/profile_playback_provider_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';

void main() {
  group('PlaybackNotifier', () {
    test('default speed is 30x and presets are the compressed set', () {
      final notifier = PlaybackNotifier();
      expect(notifier.state.playbackSpeed, 30.0);
      expect(PlaybackNotifier.speedPresets, [1.0, 5.0, 15.0, 30.0, 60.0, 120.0]);
    });

    test('1 wall-second at 30x advances 30 dive-seconds', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(3600);
        notifier.togglePlaybackMode();
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, 30);
        notifier.pause();
      });
    });

    test('1 wall-second at 120x advances 120 dive-seconds', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(3600);
        notifier.togglePlaybackMode();
        notifier.setSpeed(120);
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, 120);
        notifier.pause();
      });
    });

    test('clamps at dive end and pauses', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(60);
        notifier.togglePlaybackMode();
        notifier.setSpeed(120);
        notifier.play();
        async.elapse(const Duration(seconds: 2));
        expect(notifier.state.currentTimestamp, 60);
        expect(notifier.state.isPlaying, isFalse);
      });
    });

    test('setSpeed clamps to the 1-120 range', () {
      final notifier = PlaybackNotifier();
      notifier.initialize(600);
      notifier.setSpeed(0.1);
      expect(notifier.state.playbackSpeed, 1.0);
      notifier.setSpeed(500);
      expect(notifier.state.playbackSpeed, 120.0);
    });

    test('seeking while playing continues from the new position', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(3600);
        notifier.togglePlaybackMode();
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        notifier.seekTo(600);
        expect(notifier.state.isPlaying, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, 630);
        notifier.pause();
      });
    });
  });
}
```

If `fake_async` is not already a dev dependency, add `fake_async: ^1.3.1` under `dev_dependencies` in `pubspec.yaml` and run `flutter pub get` (it ships with flutter_test's transitive set, so an explicit entry is usually unnecessary — try the import first).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/providers/profile_playback_provider_test.dart`
Expected: FAIL — `speedPresets` undefined, default speed 1.0, timing wrong.

- [ ] **Step 3: Rework the notifier**

In `profile_playback_provider.dart`:

1. `PlaybackState`: change the default `this.playbackSpeed = 30.0`.
2. `PlaybackNotifier`: add the presets, a fractional accumulator, and frame ticking:

```dart
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  /// Replay speed presets: dive-seconds per wall-second. A 60-minute dive
  /// replays in 1 minute at 60x.
  static const List<double> speedPresets = [1, 5, 15, 30, 60, 120];

  /// Tick interval: 40 frames per second. 40 * 0.025 = 1.0, so one
  /// wall-second advances exactly [playbackSpeed] dive-seconds.
  static const Duration _tickInterval = Duration(milliseconds: 25);

  Timer? _timer;

  /// Fractional dive-seconds accumulated between whole-second state updates.
  double _fractional = 0;

  PlaybackNotifier() : super(const PlaybackState());
```

3. Replace `play()`:

```dart
  /// Start auto-playback
  void play() {
    if (!state.isActive || state.atEnd) return;

    state = state.copyWith(isPlaying: true);
    _fractional = state.currentTimestamp.toDouble();
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }
```

4. Replace `_tick()`:

```dart
  void _tick() {
    _fractional +=
        _tickInterval.inMilliseconds / 1000.0 * state.playbackSpeed;
    final next = _fractional.floor();

    if (next >= state.maxTimestamp) {
      state = state.copyWith(currentTimestamp: state.maxTimestamp);
      pause();
    } else if (next != state.currentTimestamp) {
      state = state.copyWith(currentTimestamp: next);
    }
  }
```

5. `seekTo` resets the accumulator so playback continues from the new spot:

```dart
  void seekTo(int timestamp) {
    if (!state.isActive) return;

    final clampedTimestamp = timestamp.clamp(0, state.maxTimestamp);
    _fractional = clampedTimestamp.toDouble();
    state = state.copyWith(currentTimestamp: clampedTimestamp);
  }
```

6. `setSpeed` clamps to the new range and no longer needs a timer restart (tick math reads current speed):

```dart
  void setSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed.clamp(1.0, 120.0));
  }
```

7. `stepForward`/`stepBackward`/`skipToStart`/`skipToEnd`: after computing the new timestamp, also set `_fractional = newTimestamp.toDouble();` so a following tick continues from there.

- [ ] **Step 4: Update the speed menu in PlaybackControls**

In `playback_controls.dart`, `_SpeedSelector.itemBuilder` (lines 234-239):

```dart
      itemBuilder: (context) => [
        for (final speed in PlaybackNotifier.speedPresets)
          PopupMenuItem(
            value: speed,
            child: Text('${speed.toInt()}x'),
          ),
      ],
```

and the chip label (line 227): `'${currentSpeed.toInt()}x'`.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_log/presentation/providers/profile_playback_provider_test.dart`
Expected: PASS (all 6)

Run: `flutter analyze`
Expected: No issues (catches any call sites relying on removed behavior).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(playback): frame-based ticking with compressed replay speeds"
```

---

### Task 4: Position utilities and review provider

**Files:**
- Create: `lib/features/dive_log/domain/services/profile_position.dart`
- Create: `lib/features/dive_log/presentation/providers/profile_review_provider.dart`
- Test: `test/features/dive_log/domain/services/profile_position_test.dart` (create)

**Interfaces:**
- Consumes: `DiveProfilePoint` (`lib/features/dive_log/domain/entities/dive.dart:755`), `TankPressurePoint` (`dive.dart:878`, fields `timestamp` seconds and `pressure` bar).
- Produces:
  - `int? indexForTimestamp(List<DiveProfilePoint> profile, int timestamp)` — index of the nearest sample with `timestamp <= t`, clamped to the profile range; `null` for an empty profile.
  - `double? pressureAtTimestamp(List<TankPressurePoint> points, int timestamp)` — pressure of the nearest point with `timestamp <= t`; `null` if the list is empty or all points are after `t`.
  - `profileReviewProvider` — `StateProvider.family<int?, String>` holding the review position as a timestamp in dive-seconds (null = no position selected).

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/services/profile_position_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

void main() {
  final profile = [
    const DiveProfilePoint(timestamp: 0, depth: 0),
    const DiveProfilePoint(timestamp: 10, depth: 5),
    const DiveProfilePoint(timestamp: 20, depth: 10),
    const DiveProfilePoint(timestamp: 40, depth: 12),
  ];

  group('indexForTimestamp', () {
    test('exact match', () => expect(indexForTimestamp(profile, 20), 2));
    test('between samples returns earlier sample',
        () => expect(indexForTimestamp(profile, 25), 2));
    test('before start clamps to 0',
        () => expect(indexForTimestamp(profile, -5), 0));
    test('after end clamps to last',
        () => expect(indexForTimestamp(profile, 999), 3));
    test('empty profile returns null',
        () => expect(indexForTimestamp(const [], 10), isNull));
  });

  group('pressureAtTimestamp', () {
    final points = [
      const TankPressurePoint(timestamp: 0, pressure: 200),
      const TankPressurePoint(timestamp: 60, pressure: 180),
      const TankPressurePoint(timestamp: 120, pressure: 160),
    ];
    test('exact match', () => expect(pressureAtTimestamp(points, 60), 180));
    test('between points returns earlier value',
        () => expect(pressureAtTimestamp(points, 90), 180));
    test('after last returns last',
        () => expect(pressureAtTimestamp(points, 999), 160));
    test('empty returns null',
        () => expect(pressureAtTimestamp(const [], 10), isNull));
  });
}
```

Check `TankPressurePoint`'s actual constructor at `dive.dart:878` (field names may be `timestamp`/`pressure`; adjust if different).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/profile_position_test.dart`
Expected: FAIL — file `profile_position.dart` does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/dive_log/domain/services/profile_position.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Index of the profile sample nearest to [timestamp] without going past it.
///
/// Binary search over sample timestamps. Clamps to the first/last sample for
/// out-of-range values. Returns null for an empty profile.
int? indexForTimestamp(List<DiveProfilePoint> profile, int timestamp) {
  if (profile.isEmpty) return null;
  if (timestamp <= profile.first.timestamp) return 0;
  if (timestamp >= profile.last.timestamp) return profile.length - 1;

  var low = 0;
  var high = profile.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (profile[mid].timestamp <= timestamp) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

/// Pressure of the nearest tank sample at or before [timestamp], in bar.
///
/// Returns null if [points] is empty. Values before the first sample return
/// the first sample's pressure (tank starts full at its first reading).
double? pressureAtTimestamp(List<TankPressurePoint> points, int timestamp) {
  if (points.isEmpty) return null;
  if (timestamp <= points.first.timestamp) return points.first.pressure;
  if (timestamp >= points.last.timestamp) return points.last.pressure;

  var low = 0;
  var high = points.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (points[mid].timestamp <= timestamp) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return points[low].pressure;
}
```

Create `lib/features/dive_log/presentation/providers/profile_review_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';

/// Unified review position for the fullscreen profile view, as a timestamp
/// in dive-seconds. Written by chart scrubbing, the transport slider, and
/// the playback ticker; read by the chart cursor and the instrument tiles.
///
/// Keyed by dive ID. Null means no position is selected.
final profileReviewProvider = StateProvider.family<int?, String>(
  (ref, diveId) => null,
);
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/domain/services/profile_position_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): position utilities and unified review provider"
```

---

### Task 5: Tile preference settings

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`SettingsKeys` ~line 42, `AppSettings` ~line 74, `copyWith` ~line 423, `SettingsNotifier` ~line 664, plus its load/save methods)
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart` (extend — this file exercises the real notifier)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `AppSettings.fullscreenTileOrder` — `List<String>` (default `const []` = use built-in priority order)
  - `AppSettings.fullscreenHiddenTiles` — `List<String>` (default `const []`)
  - `SettingsNotifier.setFullscreenTilePreferences({required List<String> order, required List<String> hidden})` — persists both.

- [ ] **Step 1: Write the failing test**

Open `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, study how it constructs the real `SettingsNotifier` (it seeds `SharedPreferences.setMockInitialValues`), and add in the same style:

```dart
  test('fullscreen tile preferences persist and reload', () async {
    SharedPreferences.setMockInitialValues({});
    // ... construct notifier the same way the surrounding tests do ...

    await notifier.setFullscreenTilePreferences(
      order: ['depth', 'runtime', 'ppO2'],
      hidden: ['heartRate'],
    );

    expect(notifier.state.fullscreenTileOrder, ['depth', 'runtime', 'ppO2']);
    expect(notifier.state.fullscreenHiddenTiles, ['heartRate']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('fullscreen_tile_order'), [
      'depth',
      'runtime',
      'ppO2',
    ]);
    expect(prefs.getStringList('fullscreen_hidden_tiles'), ['heartRate']);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: FAIL — compile error, no such field/method.

- [ ] **Step 3: Implement**

In `settings_providers.dart`, following the existing pattern for every field:

1. `SettingsKeys`:

```dart
  static const String fullscreenTileOrder = 'fullscreen_tile_order';
  static const String fullscreenHiddenTiles = 'fullscreen_hidden_tiles';
```

2. `AppSettings`: add fields with defaults, mirror in the const constructor and `copyWith`:

```dart
  /// Instrument tile order for the fullscreen profile view.
  /// Empty means the built-in priority order.
  final List<String> fullscreenTileOrder;

  /// Instrument tiles the user has hidden in the fullscreen profile view.
  final List<String> fullscreenHiddenTiles;
```

Constructor defaults: `this.fullscreenTileOrder = const [], this.fullscreenHiddenTiles = const [],`.

3. Loading (find where other keys are read from `SharedPreferences` in the notifier's load path):

```dart
      fullscreenTileOrder:
          prefs.getStringList(SettingsKeys.fullscreenTileOrder) ?? const [],
      fullscreenHiddenTiles:
          prefs.getStringList(SettingsKeys.fullscreenHiddenTiles) ?? const [],
```

4. Saving (in `_saveSettings`, ~line 757, alongside the other writes):

```dart
    await prefs.setStringList(
      SettingsKeys.fullscreenTileOrder,
      state.fullscreenTileOrder,
    );
    await prefs.setStringList(
      SettingsKeys.fullscreenHiddenTiles,
      state.fullscreenHiddenTiles,
    );
```

5. Notifier setter (with the other setters, ~line 764+):

```dart
  Future<void> setFullscreenTilePreferences({
    required List<String> order,
    required List<String> hidden,
  }) async {
    state = state.copyWith(
      fullscreenTileOrder: order,
      fullscreenHiddenTiles: hidden,
    );
    await _saveSettings();
  }
```

- [ ] **Step 4: Run analyze to find broken test mocks**

Run: `flutter analyze`
Expected: errors in the test mocks that implement `SettingsNotifier` WITHOUT a `noSuchMethod` fallback (project memory says ~4 sites). For each flagged mock, add:

```dart
  @override
  Future<void> setFullscreenTilePreferences({
    required List<String> order,
    required List<String> hidden,
  }) async {
    state = state.copyWith(
      fullscreenTileOrder: order,
      fullscreenHiddenTiles: hidden,
    );
  }
```

Re-run `flutter analyze` until clean.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(settings): persist fullscreen instrument tile preferences"
```

---

### Task 6: Instrument tile model (candidates, preferences, deco swap, values)

Pure logic, no widgets. This is the brain of the instrument bar.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/instrument_tiles.dart`
- Test: `test/features/dive_log/presentation/widgets/instrument_tiles_test.dart` (create)

**Interfaces:**
- Consumes: `Dive`, `DiveProfilePoint`, `TankPressurePoint`, `ProfileAnalysis` (`lib/features/dive_log/data/services/profile_analysis_service.dart` — parallel curves `ndlCurve`, `ceilingCurve`, `ttsCurve`, `ppO2Curve`, `gfCurve`, `cnsCurve`, `sacCurve`/`smoothedSacCurve`, `ascentRates`, `decoStatuses`), `indexForTimestamp`/`pressureAtTimestamp` from Task 4.
- Produces:

```dart
enum InstrumentTileId {
  depth('depth'),
  runtime('runtime'),
  temperature('temperature'),
  ndl('ndl'),
  ceiling('ceiling'),
  tts('tts'),
  tankPressure('tankPressure'),
  ppO2('ppO2'),
  gf('gf'),
  cns('cns'),
  sac('sac'),
  heartRate('heartRate'),
  ascentRate('ascentRate');

  const InstrumentTileId(this.key);
  final String key;

  static InstrumentTileId? fromKey(String key) => ...;
}

List<InstrumentTileId> computeCandidateTiles({required Dive dive, ProfileAnalysis? analysis, Map<String, List<TankPressurePoint>>? tankPressures});
List<InstrumentTileId> applyTilePreferences({required List<InstrumentTileId> candidates, required List<String> order, required List<String> hidden});
List<InstrumentTileId> applyDecoSwap({required List<InstrumentTileId> tiles, required bool inDeco});
class InstrumentSample { /* nullable raw values at one position, metric units */ }
InstrumentSample resolveSample({required Dive dive, ProfileAnalysis? analysis, Map<String, List<TankPressurePoint>>? tankPressures, required int timestamp});
```

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/presentation/widgets/instrument_tiles_test.dart`. Build two fixtures: a recreational profile (timestamp/depth/temperature only) and a tech profile (adds `ndl`, `ceiling`, `tts`, `decoType`, `ppO2`, plus an analysis object — construct `ProfileAnalysis` directly with only the curves under test, checking its constructor in `profile_analysis_service.dart` for required arguments; pass empty lists/nulls for the rest).

`Dive` requires only `id` and `dateTime` (`dive.dart:16`); everything else has defaults. Fixture pattern used throughout Tasks 6, 9, and 10:

```dart
Dive _recDive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(
      timestamp: i * 10,
      depth: 10,
      temperature: i.isEven ? 20 : null,
    ),
  ),
);
```

(If `profile` is not a direct constructor parameter, check how existing tests attach profiles to a `Dive` — e.g. `copyWith(profile: ...)` — and follow that pattern.)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_tiles.dart';

void main() {
  group('computeCandidateTiles', () {
    test('rec dive: depth, runtime, temperature only', () {
      final dive = /* Dive fixture with profile of timestamp/depth/temperature,
                      no tanks, no analysis */;
      final tiles = computeCandidateTiles(dive: dive, analysis: null);
      expect(tiles, [
        InstrumentTileId.depth,
        InstrumentTileId.runtime,
        InstrumentTileId.temperature,
      ]);
    });

    test('tech dive adds deco and gas tiles in priority order', () {
      // Fixture with ndlCurve, ceilingCurve, ttsCurve, ppO2Curve, gfCurve
      // in analysis and tankPressures with one tank.
      final tiles = computeCandidateTiles(
        dive: techDive,
        analysis: techAnalysis,
        tankPressures: {'t1': pressurePoints},
      );
      expect(
        tiles,
        containsAllInOrder([
          InstrumentTileId.depth,
          InstrumentTileId.runtime,
          InstrumentTileId.ndl,
          InstrumentTileId.tankPressure,
          InstrumentTileId.ppO2,
          InstrumentTileId.gf,
        ]),
      );
    });
  });

  group('applyTilePreferences', () {
    final candidates = [
      InstrumentTileId.depth,
      InstrumentTileId.runtime,
      InstrumentTileId.temperature,
      InstrumentTileId.ppO2,
    ];

    test('empty prefs keep candidate order', () {
      expect(
        applyTilePreferences(candidates: candidates, order: [], hidden: []),
        candidates,
      );
    });

    test('hidden tiles are removed', () {
      final result = applyTilePreferences(
        candidates: candidates,
        order: [],
        hidden: ['temperature'],
      );
      expect(result, isNot(contains(InstrumentTileId.temperature)));
    });

    test('custom order applies, unknown keys ignored, unlisted appended', () {
      final result = applyTilePreferences(
        candidates: candidates,
        order: ['ppO2', 'depth', 'bogus'],
        hidden: [],
      );
      expect(result.take(2), [InstrumentTileId.ppO2, InstrumentTileId.depth]);
      expect(result.length, candidates.length);
    });
  });

  group('applyDecoSwap', () {
    final all = [
      InstrumentTileId.depth,
      InstrumentTileId.ndl,
      InstrumentTileId.ceiling,
      InstrumentTileId.tts,
    ];
    test('no deco: keep NDL, drop ceiling and TTS', () {
      expect(applyDecoSwap(tiles: all, inDeco: false), [
        InstrumentTileId.depth,
        InstrumentTileId.ndl,
      ]);
    });
    test('in deco: drop NDL, keep ceiling and TTS', () {
      expect(applyDecoSwap(tiles: all, inDeco: true), [
        InstrumentTileId.depth,
        InstrumentTileId.ceiling,
        InstrumentTileId.tts,
      ]);
    });
  });

  group('resolveSample', () {
    test('reads point fields and curve values at the derived index', () {
      final sample = resolveSample(
        dive: techDive,
        analysis: techAnalysis,
        tankPressures: {'t1': pressurePoints},
        timestamp: 300,
      );
      expect(sample.depthMeters, isNotNull);
      expect(sample.runtimeSeconds, 300);
      expect(sample.tankPressuresBar, isNotEmpty);
    });

    test('null-at-position values stay null (temperature gap)', () {
      final sample = resolveSample(dive: recDiveNoTemp, analysis: null, timestamp: 60);
      expect(sample.temperatureCelsius, isNull);
    });

    test('inDeco reflects decoType at the position', () {
      final sample = resolveSample(dive: techDive, analysis: techAnalysis, timestamp: decoTimestamp);
      expect(sample.inDeco, isTrue);
    });
  });
}
```

Fill the fixtures with real constructors — check `Dive`'s required constructor arguments in `dive.dart:16` and construct minimal instances (id, dateTime, profile, tanks as needed). `decoType` on `DiveProfilePoint`: 2 = deco per the entity docs (`dive.dart:755-780`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/instrument_tiles_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/dive_log/presentation/widgets/instrument_tiles.dart`:

```dart
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

/// Identifiers for instrument bar tiles. [key] is the persisted string used
/// in settings; never rename a key without a migration.
enum InstrumentTileId {
  depth('depth'),
  runtime('runtime'),
  temperature('temperature'),
  ndl('ndl'),
  ceiling('ceiling'),
  tts('tts'),
  tankPressure('tankPressure'),
  ppO2('ppO2'),
  gf('gf'),
  cns('cns'),
  sac('sac'),
  heartRate('heartRate'),
  ascentRate('ascentRate');

  const InstrumentTileId(this.key);
  final String key;

  static InstrumentTileId? fromKey(String key) {
    for (final id in values) {
      if (id.key == key) return id;
    }
    return null;
  }
}

/// Priority order for candidate tiles. Depth and runtime always lead.
const List<InstrumentTileId> _priorityOrder = [
  InstrumentTileId.depth,
  InstrumentTileId.runtime,
  InstrumentTileId.temperature,
  InstrumentTileId.ndl,
  InstrumentTileId.ceiling,
  InstrumentTileId.tts,
  InstrumentTileId.tankPressure,
  InstrumentTileId.ppO2,
  InstrumentTileId.gf,
  InstrumentTileId.cns,
  InstrumentTileId.sac,
  InstrumentTileId.heartRate,
  InstrumentTileId.ascentRate,
];

/// Tiles the dive's data can actually populate, in priority order.
List<InstrumentTileId> computeCandidateTiles({
  required Dive dive,
  ProfileAnalysis? analysis,
  Map<String, List<TankPressurePoint>>? tankPressures,
}) {
  final profile = dive.profile;
  bool anyPoint(bool Function(DiveProfilePoint) test) => profile.any(test);

  final available = <InstrumentTileId>{
    if (profile.isNotEmpty) InstrumentTileId.depth,
    if (profile.isNotEmpty) InstrumentTileId.runtime,
    if (anyPoint((p) => p.temperature != null)) InstrumentTileId.temperature,
    if ((analysis?.ndlCurve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.ndl != null))
      InstrumentTileId.ndl,
    if ((analysis?.ceilingCurve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.ceiling != null))
      InstrumentTileId.ceiling,
    if ((analysis?.ttsCurve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.tts != null))
      InstrumentTileId.tts,
    if (tankPressures != null &&
        tankPressures.values.any((points) => points.isNotEmpty))
      InstrumentTileId.tankPressure,
    if ((analysis?.ppO2Curve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.ppO2 != null))
      InstrumentTileId.ppO2,
    if (analysis?.gfCurve?.isNotEmpty ?? false) InstrumentTileId.gf,
    if ((analysis?.cnsCurve?.isNotEmpty ?? false) ||
        anyPoint((p) => p.cns != null))
      InstrumentTileId.cns,
    if (analysis?.smoothedSacCurve?.isNotEmpty ?? false)
      InstrumentTileId.sac,
    if (anyPoint((p) => p.heartRate != null)) InstrumentTileId.heartRate,
    if (analysis?.ascentRates?.isNotEmpty ?? false)
      InstrumentTileId.ascentRate,
  };

  return [
    for (final id in _priorityOrder)
      if (available.contains(id)) id,
  ];
}

/// Applies the user's persisted order and hidden set on top of [candidates].
///
/// Unknown keys in [order] are ignored; candidates not mentioned in [order]
/// keep priority order and append after the ordered ones. Hidden tiles are
/// removed last, so hiding never reorders the rest.
List<InstrumentTileId> applyTilePreferences({
  required List<InstrumentTileId> candidates,
  required List<String> order,
  required List<String> hidden,
}) {
  final candidateSet = candidates.toSet();
  final ordered = <InstrumentTileId>[
    for (final key in order)
      if (InstrumentTileId.fromKey(key) case final id?)
        if (candidateSet.contains(id)) id,
  ];
  final remaining = [
    for (final id in candidates)
      if (!ordered.contains(id)) id,
  ];
  final hiddenSet = hidden.toSet();
  return [
    for (final id in [...ordered, ...remaining])
      if (!hiddenSet.contains(id.key)) id,
  ];
}

/// Deco-aware instrument swap, mirroring a real dive computer: NDL shows
/// outside deco; ceiling and TTS replace it during mandatory decompression.
List<InstrumentTileId> applyDecoSwap({
  required List<InstrumentTileId> tiles,
  required bool inDeco,
}) {
  return [
    for (final id in tiles)
      if (inDeco
          ? id != InstrumentTileId.ndl
          : id != InstrumentTileId.ceiling && id != InstrumentTileId.tts)
        id,
  ];
}

/// Raw (metric, unformatted) instrument values at one review position.
class InstrumentSample {
  final int runtimeSeconds;
  final double? depthMeters;
  final double? temperatureCelsius;
  final int? ndlSeconds;
  final double? ceilingMeters;
  final int? ttsSeconds;
  final Map<String, double> tankPressuresBar;
  final double? ppO2Bar;
  final double? gfPercent;
  final double? cnsPercent;
  final double? sacRate;
  final int? heartRateBpm;
  final double? ascentRateMetersPerMin;
  final bool inDeco;

  const InstrumentSample({
    required this.runtimeSeconds,
    this.depthMeters,
    this.temperatureCelsius,
    this.ndlSeconds,
    this.ceilingMeters,
    this.ttsSeconds,
    this.tankPressuresBar = const {},
    this.ppO2Bar,
    this.gfPercent,
    this.cnsPercent,
    this.sacRate,
    this.heartRateBpm,
    this.ascentRateMetersPerMin,
    this.inDeco = false,
  });
}

/// Resolves instrument values at [timestamp] (dive-seconds).
InstrumentSample resolveSample({
  required Dive dive,
  ProfileAnalysis? analysis,
  Map<String, List<TankPressurePoint>>? tankPressures,
  required int timestamp,
}) {
  final index = indexForTimestamp(dive.profile, timestamp);
  if (index == null) {
    return InstrumentSample(runtimeSeconds: timestamp);
  }
  final point = dive.profile[index];

  T? curveAt<T>(List<T>? curve) =>
      (curve != null && index < curve.length) ? curve[index] : null;

  return InstrumentSample(
    runtimeSeconds: point.timestamp,
    depthMeters: point.depth,
    temperatureCelsius: point.temperature,
    ndlSeconds: curveAt(analysis?.ndlCurve) ?? point.ndl,
    ceilingMeters: curveAt(analysis?.ceilingCurve) ?? point.ceiling,
    ttsSeconds: curveAt(analysis?.ttsCurve) ?? point.tts,
    tankPressuresBar: {
      if (tankPressures != null)
        for (final entry in tankPressures.entries)
          if (pressureAtTimestamp(entry.value, timestamp) case final p?)
            entry.key: p,
    },
    ppO2Bar: curveAt(analysis?.ppO2Curve) ?? point.ppO2,
    gfPercent: curveAt(analysis?.gfCurve),
    cnsPercent: curveAt(analysis?.cnsCurve) ?? point.cns,
    sacRate: curveAt(analysis?.smoothedSacCurve),
    heartRateBpm: point.heartRate,
    ascentRateMetersPerMin: curveAt(analysis?.ascentRates) ?? point.ascentRate,
    inDeco: point.decoType == 2,
  );
}
```

Type check against the real `ProfileAnalysis` field types (`ndlCurve` etc. — element types may be `int` or `double`; `ascentRates` may be a list of a value class rather than doubles — check `profile_analysis_service.dart:195` and adapt `curveAt` usage; if `ascentRates` elements are objects, take their rate field). The analyzer and the tests are the arbiter.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/instrument_tiles_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): instrument tile model with adaptive deco-aware selection"
```

---

### Task 7: ReadoutTile widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/readout_tile.dart`
- Test: `test/features/dive_log/presentation/widgets/readout_tile_test.dart` (create)

**Interfaces:**
- Consumes: nothing project-specific (pure presentational widget).
- Produces: `ReadoutTile(label: String, value: String?, {Color? valueColor})` — small uppercase label above a bold tabular-figures value; renders an em dash when `value` is null. Task 8 builds the bar from these.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/readout_tile.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('renders label and value', (tester) async {
    await tester.pumpWidget(
      wrap(const ReadoutTile(label: 'DEPTH', value: '18.4 m')),
    );
    expect(find.text('DEPTH'), findsOneWidget);
    expect(find.text('18.4 m'), findsOneWidget);
  });

  testWidgets('null value renders an em dash', (tester) async {
    await tester.pumpWidget(wrap(const ReadoutTile(label: 'TEMP', value: null)));
    expect(find.text('—'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/readout_tile_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/dive_log/presentation/widgets/readout_tile.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

/// A single instrument readout: small uppercase label over a bold value.
///
/// Renders an em dash when [value] is null so the instrument bar keeps a
/// stable layout through data gaps during playback.
class ReadoutTile extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;

  const ReadoutTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value ?? '—',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? colorScheme.onSurface,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test**

Run: `flutter test test/features/dive_log/presentation/widgets/readout_tile_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): readout tile widget for instrument bar"
```

---

### Task 8: Transport controls with minimap slider

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_transport_controls.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_transport_controls_test.dart` (create)

**Interfaces:**
- Consumes: `playbackProvider(diveId)` + `PlaybackNotifier` (Task 3), `profileReviewProvider(diveId)` (Task 4), `List<DiveProfilePoint>` for the minimap.
- Produces: `ProfileTransportControls(diveId: String, profile: List<DiveProfilePoint>)` — one row: skip-start, play/pause, skip-end, minimap slider, `current / total` time, speed chip. Every position change writes BOTH `playbackProvider.seekTo` and `profileReviewProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _diveId = 'd1';

List<DiveProfilePoint> _profile() => List.generate(
  61,
  (i) => DiveProfilePoint(timestamp: i * 10, depth: 10),
);

void main() {
  late ProviderContainer container;

  Widget wrap() {
    container = ProviderContainer();
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileTransportControls(diveId: _diveId, profile: _profile()),
        ),
      ),
    );
  }

  testWidgets('play button starts playback', (tester) async {
    await tester.pumpWidget(wrap());
    // The widget initializes+activates playback on first build.
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(container.read(playbackProvider(_diveId)).isPlaying, isTrue);
    container.read(playbackProvider(_diveId).notifier).pause();
  });

  testWidgets('slider seek updates playback and review position', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(120, 0));
    await tester.pump();

    expect(container.read(playbackProvider(_diveId)).currentTimestamp,
        greaterThan(0));
    expect(container.read(profileReviewProvider(_diveId)), greaterThan(0));
  });

  testWidgets('speed chip shows current speed', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('30x'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_transport_controls_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/dive_log/presentation/widgets/profile_transport_controls.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Playback transport for the fullscreen profile: skip / play / skip,
/// a minimap scrub slider, elapsed / total time, and a speed chip.
class ProfileTransportControls extends ConsumerStatefulWidget {
  final String diveId;
  final List<DiveProfilePoint> profile;

  const ProfileTransportControls({
    super.key,
    required this.diveId,
    required this.profile,
  });

  @override
  ConsumerState<ProfileTransportControls> createState() =>
      _ProfileTransportControlsState();
}

class _ProfileTransportControlsState
    extends ConsumerState<ProfileTransportControls> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.profile.isEmpty) return;
      final notifier = ref.read(playbackProvider(widget.diveId).notifier);
      final state = ref.read(playbackProvider(widget.diveId));
      if (state.maxTimestamp == 0) {
        notifier.initialize(widget.profile.last.timestamp);
      }
      if (!state.isActive) {
        notifier.togglePlaybackMode();
      }
    });
  }

  void _seek(int timestamp) {
    ref.read(playbackProvider(widget.diveId).notifier).seekTo(timestamp);
    ref.read(profileReviewProvider(widget.diveId).notifier).state = timestamp;
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider(widget.diveId));
    final notifier = ref.read(playbackProvider(widget.diveId).notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = widget.profile.isNotEmpty;

    // Keep the review position in sync with the ticker.
    ref.listen(playbackProvider(widget.diveId), (previous, next) {
      if (next.isActive &&
          previous?.currentTimestamp != next.currentTimestamp) {
        ref.read(profileReviewProvider(widget.diveId).notifier).state =
            next.currentTimestamp;
      }
    });

    return Row(
      children: [
        IconButton(
          onPressed: enabled && !playback.atStart
              ? () => _seek(0)
              : null,
          icon: const Icon(Icons.skip_previous),
          tooltip: context.l10n.diveLog_playback_tooltip_skipStart,
          visualDensity: VisualDensity.compact,
        ),
        IconButton.filled(
          onPressed: !enabled
              ? null
              : playback.atEnd && !playback.isPlaying
                  ? () {
                      notifier.skipToStart();
                      notifier.play();
                    }
                  : notifier.togglePlayPause,
          icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
          tooltip: playback.isPlaying
              ? context.l10n.diveLog_playback_tooltip_pause
              : context.l10n.diveLog_playback_tooltip_play,
        ),
        IconButton(
          onPressed: enabled && !playback.atEnd
              ? () => _seek(playback.maxTimestamp)
              : null,
          icon: const Icon(Icons.skip_next),
          tooltip: context.l10n.diveLog_playback_tooltip_skipEnd,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MinimapPainter(
                    profile: widget.profile,
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: playback.progress.clamp(0.0, 1.0),
                  onChanged: enabled
                      ? (v) =>
                          _seek((v * playback.maxTimestamp).round())
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${playback.formattedTime} / ${playback.formattedTotalTime}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<double>(
          initialValue: playback.playbackSpeed,
          tooltip: context.l10n.diveLog_playback_tooltip_speed,
          onSelected: notifier.setSpeed,
          itemBuilder: (context) => [
            for (final speed in PlaybackNotifier.speedPresets)
              PopupMenuItem(value: speed, child: Text('${speed.toInt()}x')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${playback.playbackSpeed.toInt()}x',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a filled depth outline of the whole dive inside the slider track,
/// so the scrub bar doubles as a minimap.
class _MinimapPainter extends CustomPainter {
  final List<DiveProfilePoint> profile;
  final Color color;

  _MinimapPainter({required this.profile, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    final maxTime = profile.last.timestamp;
    final maxDepth = profile
        .map((p) => p.depth)
        .reduce((a, b) => a > b ? a : b);
    if (maxTime <= 0 || maxDepth <= 0) return;

    final path = Path()..moveTo(0, 0);
    for (final point in profile) {
      path.lineTo(
        point.timestamp / maxTime * size.width,
        point.depth / maxDepth * size.height,
      );
    }
    path
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) =>
      oldDelegate.profile != profile || oldDelegate.color != color;
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_transport_controls_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): transport controls with minimap scrub slider"
```

---

### Task 9: Instrument bar with customize sheet

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart`
- Modify: `lib/l10n/arb/app_en.arb` + all 10 locale arbs (2 new keys)
- Test: `test/features/dive_log/presentation/widgets/profile_instrument_bar_test.dart` (create)

**Interfaces:**
- Consumes: Tasks 4-8 — `profileReviewProvider`, `computeCandidateTiles` / `applyTilePreferences` / `applyDecoSwap` / `resolveSample`, `ReadoutTile`, `ProfileTransportControls`, `settingsProvider` (`fullscreenTileOrder` / `fullscreenHiddenTiles`, `SettingsNotifier.setFullscreenTilePreferences`), `UnitFormatter`.
- Produces: `ProfileInstrumentBar(diveId: String, dive: Dive, analysis: ProfileAnalysis?, tankPressures: Map<String, List<TankPressurePoint>>?)` — a `Column` of `ProfileTransportControls` and the tile row, plus a tune button opening the customize sheet.

- [ ] **Step 1: Add l10n strings**

In `lib/l10n/arb/app_en.arb` add:

```json
  "diveLog_instruments_customize": "Customize instruments",
  "diveLog_instruments_customizeHint": "Toggle instruments on or off. Drag to reorder.",
```

Add translations to the other 10 arbs (same keys):

| Locale | customize | customizeHint |
|--------|-----------|---------------|
| ar | "تخصيص الأدوات" | "قم بتشغيل الأدوات أو إيقافها. اسحب لإعادة الترتيب." |
| de | "Instrumente anpassen" | "Instrumente ein- oder ausschalten. Zum Sortieren ziehen." |
| es | "Personalizar instrumentos" | "Activa o desactiva instrumentos. Arrastra para reordenar." |
| fr | "Personnaliser les instruments" | "Activez ou desactivez les instruments. Faites glisser pour reorganiser." |
| he | "התאמה אישית של מכשירים" | "הפעל או כבה מכשירים. גרור כדי לסדר מחדש." |
| hu | "Muszerek testreszabasa" | "Kapcsolja be vagy ki a muszereket. Huzza az atrendezeshez." |
| it | "Personalizza strumenti" | "Attiva o disattiva gli strumenti. Trascina per riordinare." |
| nl | "Instrumenten aanpassen" | "Schakel instrumenten in of uit. Sleep om te herschikken." |
| pt | "Personalizar instrumentos" | "Ative ou desative instrumentos. Arraste para reordenar." |
| zh | "自定义仪表" | "开启或关闭仪表。拖动以重新排序。" |

(Use proper accented characters in fr/hu — check neighboring entries in each arb for the established style; the table above strips some accents for markdown safety: use "désactivez", "réorganiser", "Műszerek testreszabása", "Kapcsolja be vagy ki a műszereket. Húzza az átrendezéshez.")

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart` without errors.

- [ ] **Step 2: Write the failing tests**

Tile labels reuse existing legend keys (`diveLog_legend_label_depth`, `_temp`, `_ndl`, `_ceiling`, `_tts`, `_pressure`, `_ppO2`, `_gfPercent`, `_cns`, `_sac`, `_heartRate`, plus `diveLog_tooltip_time` for runtime — verify each exists in `app_en.arb` with grep; substitute the closest existing key when a name differs, and only add a genuinely missing label to all 11 arbs).

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/readout_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([AppSettings? initial])
    : super(initial ?? const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _recDive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

void main() {
  late ProviderContainer container;

  Widget wrap(Dive dive, {AppSettings? settings}) {
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _FakeSettingsNotifier(settings),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileInstrumentBar(
            diveId: dive.id,
            dive: dive,
            analysis: null,
            tankPressures: null,
          ),
        ),
      ),
    );
  }

  testWidgets('rec dive shows depth, runtime, temperature tiles only', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_recDive()));
    await tester.pump();
    expect(find.byType(ReadoutTile), findsNWidgets(3));
  });

  testWidgets('tiles update when the review position changes', (tester) async {
    await tester.pumpWidget(wrap(_recDive()));
    await tester.pump();

    container.read(profileReviewProvider('d1').notifier).state = 100;
    await tester.pump();

    // Depth at t=100 for the fixture; assert the formatted value appears.
    // (Fixture: depth 10.0 m at timestamp 100 -> default metric "10.0 m".)
    expect(find.textContaining('10.0'), findsWidgets);
  });

  testWidgets('hidden tiles are not rendered', (tester) async {
    await tester.pumpWidget(
      wrap(
        _recDive(),
        settings: const AppSettings(fullscreenHiddenTiles: ['temperature']),
      ),
    );
    await tester.pump();
    expect(find.byType(ReadoutTile), findsNWidgets(2));
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_instrument_bar_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 4: Implement**

Create `lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart`. Key structure (formatting helpers follow the patterns from the old `_buildFullMetricsTable` at `dive_detail_page.dart:5141-5330` — NDL as `m:ss` or "Deco", TTS as `N min`, ppO2 as `0.92 bar`, GF as `48%`, CNS as `12.3%`):

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_tiles.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';
import 'package:submersion/features/dive_log/presentation/widgets/readout_tile.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The bottom instrument strip of the fullscreen profile view: playback
/// transport plus adaptive dive-computer readout tiles.
class ProfileInstrumentBar extends ConsumerWidget {
  final String diveId;
  final Dive dive;
  final ProfileAnalysis? analysis;
  final Map<String, List<TankPressurePoint>>? tankPressures;

  const ProfileInstrumentBar({
    super.key,
    required this.diveId,
    required this.dive,
    required this.analysis,
    required this.tankPressures,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final reviewTimestamp = ref.watch(profileReviewProvider(diveId));

    final candidates = computeCandidateTiles(
      dive: dive,
      analysis: analysis,
      tankPressures: tankPressures,
    );
    final preferred = applyTilePreferences(
      candidates: candidates,
      order: settings.fullscreenTileOrder,
      hidden: settings.fullscreenHiddenTiles,
    );
    final sample = resolveSample(
      dive: dive,
      analysis: analysis,
      tankPressures: tankPressures,
      timestamp: reviewTimestamp ?? 0,
    );
    final tiles = applyDecoSwap(tiles: preferred, inDeco: sample.inDeco);

    final tileWidgets = [
      for (final id in tiles)
        ReadoutTile(
          label: _label(context, id),
          value: reviewTimestamp == null ? null : _value(context, id, sample, units),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ProfileTransportControls(
                  diveId: diveId,
                  profile: dive.profile,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: context.l10n.diveLog_instruments_customize,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showCustomizeSheet(
                  context,
                  ref,
                  candidates: candidates,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Wrap(spacing: 8, runSpacing: 8, children: tileWidgets);
              }
              return SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tileWidgets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => tileWidgets[i],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _label(BuildContext context, InstrumentTileId id) {
    final l10n = context.l10n;
    return switch (id) {
      InstrumentTileId.depth => l10n.diveLog_legend_label_depth,
      InstrumentTileId.runtime => l10n.diveLog_tooltip_time,
      InstrumentTileId.temperature => l10n.diveLog_legend_label_temp,
      InstrumentTileId.ndl => l10n.diveLog_legend_label_ndl,
      InstrumentTileId.ceiling => l10n.diveLog_legend_label_ceiling,
      InstrumentTileId.tts => l10n.diveLog_legend_label_tts,
      InstrumentTileId.tankPressure => l10n.diveLog_legend_label_pressure,
      InstrumentTileId.ppO2 => l10n.diveLog_legend_label_ppO2,
      InstrumentTileId.gf => l10n.diveLog_legend_label_gfPercent,
      InstrumentTileId.cns => l10n.diveLog_legend_label_cns,
      InstrumentTileId.sac => l10n.diveLog_legend_label_sac,
      InstrumentTileId.heartRate => l10n.diveLog_legend_label_heartRate,
      InstrumentTileId.ascentRate => l10n.diveLog_legend_label_ascentRate,
    };
  }

  String? _value(
    BuildContext context,
    InstrumentTileId id,
    InstrumentSample sample,
    UnitFormatter units,
  ) {
    String formatMinSec(int seconds) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return switch (id) {
      InstrumentTileId.depth => sample.depthMeters == null
          ? null
          : units.formatDepth(sample.depthMeters),
      InstrumentTileId.runtime => formatMinSec(sample.runtimeSeconds),
      InstrumentTileId.temperature => sample.temperatureCelsius == null
          ? null
          : units.formatTemperature(sample.temperatureCelsius),
      InstrumentTileId.ndl => switch (sample.ndlSeconds) {
        null => null,
        final ndl when ndl < 0 => context.l10n.diveLog_playbackStats_deco,
        final ndl when ndl >= 3600 => '>60 min',
        final ndl => formatMinSec(ndl),
      },
      InstrumentTileId.ceiling => sample.ceilingMeters == null
          ? null
          : units.formatDepth(sample.ceilingMeters),
      InstrumentTileId.tts => sample.ttsSeconds == null
          ? null
          : '${(sample.ttsSeconds! / 60).ceil()} min',
      InstrumentTileId.tankPressure => sample.tankPressuresBar.isEmpty
          ? null
          : sample.tankPressuresBar.values
                .map((p) => units.formatPressure(p))
                .join(' / '),
      InstrumentTileId.ppO2 => sample.ppO2Bar == null
          ? null
          : '${sample.ppO2Bar!.toStringAsFixed(2)} bar',
      InstrumentTileId.gf => sample.gfPercent == null
          ? null
          : '${sample.gfPercent!.toStringAsFixed(0)}%',
      InstrumentTileId.cns => sample.cnsPercent == null
          ? null
          : '${sample.cnsPercent!.toStringAsFixed(1)}%',
      InstrumentTileId.sac => sample.sacRate == null
          ? null
          : units.formatSac(sample.sacRate),
      InstrumentTileId.heartRate => sample.heartRateBpm == null
          ? null
          : '${sample.heartRateBpm} bpm',
      InstrumentTileId.ascentRate => sample.ascentRateMetersPerMin == null
          ? null
          : units.formatDepth(sample.ascentRateMetersPerMin, decimals: 0),
    };
  }

  void _showCustomizeSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<InstrumentTileId> candidates,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _CustomizeSheet(
        candidates: candidates,
        labelFor: (id) => _label(context, id),
      ),
    );
  }
}

/// Reorderable list of candidate tiles with visibility switches.
class _CustomizeSheet extends ConsumerWidget {
  final List<InstrumentTileId> candidates;
  final String Function(InstrumentTileId) labelFor;

  const _CustomizeSheet({required this.candidates, required this.labelFor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final ordered = applyTilePreferences(
      candidates: candidates,
      order: settings.fullscreenTileOrder,
      hidden: const [],
    );
    final hidden = settings.fullscreenHiddenTiles.toSet();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.diveLog_instruments_customize,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              context.l10n.diveLog_instruments_customizeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Flexible(
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: true,
              onReorder: (oldIndex, newIndex) {
                final items = [...ordered];
                if (newIndex > oldIndex) newIndex -= 1;
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                notifier.setFullscreenTilePreferences(
                  order: [for (final id in items) id.key],
                  hidden: settings.fullscreenHiddenTiles,
                );
              },
              children: [
                for (final id in ordered)
                  SwitchListTile(
                    key: ValueKey(id.key),
                    title: Text(labelFor(id)),
                    value: !hidden.contains(id.key),
                    onChanged: (visible) {
                      final newHidden = {...hidden};
                      if (visible) {
                        newHidden.remove(id.key);
                      } else {
                        newHidden.add(id.key);
                      }
                      notifier.setFullscreenTilePreferences(
                        order: settings.fullscreenTileOrder,
                        hidden: newHidden.toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Verify `UnitFormatter` method names (`formatSac` — check `lib/core/utils/unit_formatter.dart`; if the SAC formatter has a different name or signature, use it) and the exact legend l10n key names via grep in `app_en.arb`. If `diveLog_legend_label_sac`, `_tts`, `_ascentRate`, etc. differ, use the actual keys.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_instrument_bar_test.dart`
Expected: PASS

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): adaptive instrument bar with customize sheet"
```

---

### Task 10: Fullscreen profile page

**Files:**
- Create: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`
- Test: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart` (create)

**Interfaces:**
- Consumes: `diveProvider` (`dive_providers.dart:143`, `FutureProvider.family<Dive?, String>`), `profileAnalysisProvider` (`profile_analysis_provider.dart:630`), `gasSwitchesProvider`, `tankPressuresProvider`, `showMaxDepthMarkerProvider` / `showPressureThresholdMarkersProvider` (`settings_providers.dart:1381/1385`), `ProfileMarkersService`, `DiveProfileChart` (+ Task 1/2 params), `ProfileInstrumentBar`, `profileReviewProvider`, `playbackProvider`, `indexForTimestamp`.
- Produces: `FullscreenProfilePage(diveId: String)` — public page pushed by Task 11.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Fake settings notifier as in earlier tasks.

Dive _dive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

Widget _wrap(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const FullscreenProfilePage(diveId: 'd1'),
  ),
);

List<Override> _defaultOverrides() => [
  settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
  diveProvider.overrideWith((ref, id) async => _dive()),
  profileAnalysisProvider.overrideWith((ref, id) async => null),
  gasSwitchesProvider.overrideWith((ref, id) async => []),
  tankPressuresProvider.overrideWith((ref, id) async => {}),
];

void main() {
  testWidgets('renders chart and instrument bar', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(ProfileInstrumentBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('chart fills most of the screen height', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    final chartHeight = tester.getSize(find.byType(DiveProfileChart)).height;
    expect(chartHeight, greaterThan(500));
  });

  testWidgets('close button pops the page', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(DiveProfileChart), findsNothing);
  });
}
```

(Check the exact override syntax against the providers' Riverpod version — for legacy `FutureProvider.family`, `overrideWith((ref, arg) => ...)` is correct in Riverpod 3; if the project is on an older API, use the pattern found in existing page tests such as `test/features/statistics/presentation/pages/records_page_test.dart`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart`. Reuse the chart wiring from the old `_FullscreenProfilePage` build (`dive_detail_page.dart:4942-5021`) and its `_calculateMarkers` (`dive_detail_page.dart:5050-5083`), now fed from watched providers:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen dive review: full-height profile chart with a dive-computer
/// instrument bar, playback, and scrubbing (issues #443, #169).
class FullscreenProfilePage extends ConsumerStatefulWidget {
  final String diveId;

  const FullscreenProfilePage({super.key, required this.diveId});

  @override
  ConsumerState<FullscreenProfilePage> createState() =>
      _FullscreenProfilePageState();
}

class _FullscreenProfilePageState extends ConsumerState<FullscreenProfilePage> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _lifecycleListener = AppLifecycleListener(
      onInactive: () =>
          ref.read(playbackProvider(widget.diveId).notifier).pause(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Render from AsyncValue.value so background reloads never flash the UI.
    final dive = ref.watch(diveProvider(widget.diveId)).value;
    final analysis = ref.watch(profileAnalysisProvider(widget.diveId)).value;
    final gasSwitches = ref.watch(gasSwitchesProvider(widget.diveId)).value;
    final tankPressures =
        ref.watch(tankPressuresProvider(widget.diveId)).value;
    final reviewTimestamp = ref.watch(profileReviewProvider(widget.diveId));
    final showMaxDepthMarker = ref.watch(showMaxDepthMarkerProvider);
    final showPressureThresholdMarkers =
        ref.watch(showPressureThresholdMarkersProvider);

    if (dive == null) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              const Center(child: CircularProgressIndicator()),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(playbackProvider(widget.diveId).notifier);

    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): () {
              final state = ref.read(playbackProvider(widget.diveId));
              if (state.isActive) notifier.togglePlayPause();
            },
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                notifier.stepBackward,
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                notifier.stepForward,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).pop(),
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: DiveProfileChart(
                      profile: dive.profile,
                      diveDuration: dive.effectiveRuntime,
                      maxDepth: dive.maxDepth,
                      legendLeading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: context
                                .l10n.diveLog_fullscreenProfile_close,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              context.l10n.diveLog_fullscreenProfile_title(
                                dive.diveNumber ?? 0,
                              ),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      // Analysis curves: identical wiring to the old
                      // fullscreen call site (dive_detail_page.dart:4946-4990)
                      ceilingCurve: analysis?.ceilingCurve,
                      ascentRates: analysis?.ascentRates,
                      events: analysis?.events,
                      ndlCurve: analysis?.ndlCurve,
                      sacCurve: analysis?.smoothedSacCurve,
                      ppO2Curve: analysis?.ppO2Curve,
                      o2SensorCurves: analysis?.o2SensorCurves,
                      ppO2FromSensorAverage:
                          analysis?.ppO2FromSensorAverage ?? false,
                      ppN2Curve: analysis?.ppN2Curve,
                      ppHeCurve: analysis?.ppHeCurve,
                      modCurve: analysis?.modCurve,
                      densityCurve: analysis?.densityCurve,
                      gfCurve: analysis?.gfCurve,
                      surfaceGfCurve: analysis?.surfaceGfCurve,
                      meanDepthCurve: analysis?.meanDepthCurve,
                      ttsCurve: analysis?.ttsCurve,
                      cnsCurve: analysis?.cnsCurve,
                      otuCurve: analysis?.otuCurve,
                      tankVolume: dive.tanks
                          .where((t) => t.volume != null && t.volume! > 0)
                          .map((t) => t.volume!)
                          .firstOrNull,
                      sacNormalizationFactor:
                          calculateSacNormalizationFactor(dive, analysis),
                      markers: _calculateMarkers(
                        dive: dive,
                        analysis: analysis,
                        tankPressures: tankPressures,
                        showMaxDepth: showMaxDepthMarker,
                        showPressureThresholds: showPressureThresholdMarkers,
                      ),
                      showMaxDepthMarker: showMaxDepthMarker,
                      showPressureThresholdMarkers:
                          showPressureThresholdMarkers,
                      tanks: dive.tanks,
                      tankPressures: tankPressures,
                      gasSwitches: gasSwitches,
                      gasSegments: (dive.tanks.isEmpty || dive.profile.isEmpty)
                          ? null
                          : buildGasUsageSegments(
                              tanks: dive.tanks,
                              gasSwitches: gasSwitches ?? const [],
                              diveDurationSeconds:
                                  dive.profile.last.timestamp,
                            ),
                      diveDurationSeconds: dive.profile.isEmpty
                          ? null
                          : dive.profile.last.timestamp,
                      highlightedTimestamp: reviewTimestamp,
                      onPointSelected: (index) {
                        if (index == null || index >= dive.profile.length) {
                          return;
                        }
                        final timestamp = dive.profile[index].timestamp;
                        ref
                                .read(
                                  profileReviewProvider(widget.diveId).notifier,
                                )
                                .state =
                            timestamp;
                        // Keep playback in sync so play resumes from here.
                        final playback =
                            ref.read(playbackProvider(widget.diveId));
                        if (playback.isActive) {
                          notifier.seekTo(timestamp);
                        }
                      },
                    ),
                  ),
                ),
                ProfileInstrumentBar(
                  diveId: widget.diveId,
                  dive: dive,
                  analysis: analysis,
                  tankPressures: tankPressures,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ProfileMarker> _calculateMarkers({
    required Dive dive,
    required ProfileAnalysis? analysis,
    required Map<String, List<TankPressurePoint>>? tankPressures,
    required bool showMaxDepth,
    required bool showPressureThresholds,
  }) {
    final markers = <ProfileMarker>[];
    if (dive.profile.isEmpty) return markers;

    if (showMaxDepth && analysis != null) {
      final maxDepthMarker = ProfileMarkersService.getMaxDepthMarker(
        profile: dive.profile,
        maxDepthTimestamp: analysis.maxDepthTimestamp,
        maxDepth: analysis.maxDepth,
      );
      if (maxDepthMarker != null) markers.add(maxDepthMarker);
    }

    if (showPressureThresholds && dive.tanks.isNotEmpty) {
      markers.addAll(
        ProfileMarkersService.getPressureThresholdMarkers(
          profile: dive.profile,
          tanks: dive.tanks,
          tankPressures: tankPressures,
        ),
      );
    }

    return markers;
  }
}
```

Add missing imports as the analyzer demands (`ProfileAnalysis` import from `profile_analysis_service.dart`, `calculateSacNormalizationFactor` — grep for where the old page imported it).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`
Expected: PASS

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(profile): fullscreen profile page with instrument bar and playback (#443, #169)"
```

---

### Task 11: Wire up navigation and delete the old fullscreen view

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_showFullscreenProfile` at ~2550; delete `_FullscreenProfilePage` + `_FullscreenProfilePageState`, ~lines 4838-5657 region — everything belonging to those two classes including `_calculateMarkers`, `_buildMetricsTable`, `_buildFullMetricsTable`, `_buildCompactMetrics`, and their private helpers)
- Modify: `lib/l10n/arb/*.arb` (remove orphaned keys if unused)
- Test: existing suites

**Interfaces:**
- Consumes: `FullscreenProfilePage` (Task 10).
- Produces: the expand button opens the new page. No public API.

- [ ] **Step 1: Rewire `_showFullscreenProfile`**

```dart
  void _showFullscreenProfile(BuildContext context, WidgetRef ref, Dive dive) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenProfilePage(diveId: dive.id),
      ),
    );
  }
```

Add the import: `package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart`.

- [ ] **Step 2: Delete the old classes**

Delete `_FullscreenProfilePage` and `_FullscreenProfilePageState` entirely from `dive_detail_page.dart`. Then run `flutter analyze` and remove imports that became unused in that file only (do not touch imports still used by the rest of the page).

- [ ] **Step 3: Clean up orphaned l10n keys**

For each of `diveLog_detail_fullscreen_touchChart`, `diveLog_detail_fullscreen_sampleData`, `diveLog_detail_fullscreen_tapChartCompact`, `diveLog_detail_fullscreen_tapChartFull`:

```bash
grep -rn "diveLog_detail_fullscreen_touchChart" lib/ --include="*.dart" | grep -v "app_localizations"
```

If a key has no remaining Dart usages, remove it (and its `@`-metadata entry if any) from ALL 11 arb files, then run `flutter gen-l10n`. Keep `diveLog_fullscreenProfile_title` and `diveLog_fullscreenProfile_close` — the new page uses them.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: No issues.

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart`
Expected: PASS

Also run any existing dive_detail_page test suite:

```bash
ls test/features/dive_log/presentation/pages/
```

Run whatever `dive_detail_page` tests exist there.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "refactor(profile): route fullscreen profile to the new page, drop old view"
```

---

### Task 12: Full verification pass

**Files:** none new.

- [ ] **Step 1: Full analyze and format check**

```bash
dart format . && flutter analyze
```
Expected: no formatting changes on the second run of `dart format .`; analyze reports "No issues found".

- [ ] **Step 2: Run the affected test files (specific files, not directories)**

```bash
flutter test \
  test/features/dive_log/presentation/widgets/dive_profile_chart_sizing_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_chart_test.dart \
  test/features/dive_log/presentation/widgets/dive_profile_panel_test.dart \
  test/features/dive_log/presentation/providers/profile_playback_provider_test.dart \
  test/features/dive_log/domain/services/profile_position_test.dart \
  test/features/dive_log/presentation/widgets/instrument_tiles_test.dart \
  test/features/dive_log/presentation/widgets/readout_tile_test.dart \
  test/features/dive_log/presentation/widgets/profile_transport_controls_test.dart \
  test/features/dive_log/presentation/widgets/profile_instrument_bar_test.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart \
  test/features/settings/presentation/providers/settings_notifier_real_test.dart
```
Expected: all PASS.

- [ ] **Step 3: Manual smoke test on macOS**

```bash
flutter run -d macos
```

Open a dive with a profile, tap the fullscreen icon, verify: chart fills the window; resizing the window resizes the chart; series toggles and zoom work in the header; scrubbing moves tiles; play animates the cursor with tiles updating; speed menu changes pace; tune sheet hides/reorders tiles and persists after reopening; Esc closes; Space toggles play.

- [ ] **Step 4: Commit any remaining fixes**

```bash
dart format .
git add -A
git commit -m "test(profile): fullscreen profile redesign verification fixes"
```

(Skip the commit if the tree is clean.)
