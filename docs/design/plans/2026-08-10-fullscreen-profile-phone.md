# Fullscreen Profile Phone Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the fullscreen dive profile the whole screen on phones by deleting the metric tile strip everywhere, dropping the playback transport on phone widths, and letting the page escape the app shell and the system bars (#811).

**Architecture:** `FullscreenProfilePage` gains a single `isPhone` gate read from `MediaQuery.sizeOf(context).shortestSide`. `ProfileInstrumentBar` loses its tile half and becomes the much smaller `ProfileTransportBar`. `instrument_tiles.dart` is split first, because the Perdix video overlay depends on half of it, then its tile half is deleted along with the two settings fields and two l10n keys that only the tile UI used.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod (StateNotifier), `flutter_test` widget tests, `flutter gen-l10n`.

## Global Constraints

- Work only inside the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-811-fullscreen-profile`. Pass worktree-absolute paths to Read/Edit/Write; a main-checkout absolute path silently edits `main` while the tests read the worktree copy.
- Phone/desktop gate is exactly `MediaQuery.sizeOf(context).shortestSide < 600`. Never `maxWidth`, never `MediaQuery.of(context).size.width`.
- No emojis in code, comments, or documentation.
- Never mutate objects in place; use `copyWith`.
- Anything displaying units must go through `UnitFormatter` and respect the active diver's unit settings. (No new unit-bearing UI in this plan; the rule still binds.)
- `dart format .` must leave the tree unchanged before any commit.
- `flutter analyze` must report zero issues; the project treats infos as fatal, and piping the output masks a non-zero exit.
- Widget tests must set responsive breakpoints with an explicit `MediaQuery` wrapper. `tester.binding.setSurfaceSize` alone does not reliably drive a `MediaQuery`-reading breakpoint, and a test that relies on it renders the wrong layout while appearing to pass.
- `flutter gen-l10n` must be run from the worktree directory, or the regenerated localizations land in the main checkout.

---

### Task 1: Extract the instrument sampler from the tile machinery

`instrument_tiles.dart` holds two unrelated things: tile identity/preference logic used only by the instrument bar, and `InstrumentSample`/`resolveSample`, which `perdix_face_resolver.dart` also uses. Later tasks delete the first half, so the second half must move out first. This task is a pure move with no behavior change.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/instrument_sample.dart`
- Modify: `lib/features/dive_log/presentation/widgets/instrument_tiles.dart:161-238` (remove `InstrumentSample` and `resolveSample`)
- Modify: `lib/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart:6` (import)
- Modify: `lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart:8` (import)
- Create: `test/features/dive_log/presentation/widgets/instrument_sample_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/instrument_tiles_test.dart:234-` (remove the `resolveSample` group)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `lib/features/dive_log/presentation/widgets/instrument_sample.dart` exporting
  - `class InstrumentSample` with fields `int runtimeSeconds`, `double? depthMeters`, `double? temperatureCelsius`, `int? ndlSeconds`, `double? ceilingMeters`, `int? ttsSeconds`, `Map<String, double> tankPressuresBar`, `double? ppO2Bar`, `double? gfPercent`, `double? cnsPercent`, `double? sacRate`, `int? heartRateBpm`, `double? ascentRateMetersPerMin`, `bool inDeco`
  - `InstrumentSample resolveSample({required List<DiveProfilePoint> profile, ProfileAnalysis? analysis, Map<String, List<TankPressurePoint>>? tankPressures, required int timestamp})`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/instrument_sample_test.dart`. Copy the fixtures at `instrument_tiles_test.dart:1-89` that the `resolveSample` group needs (`_techDive`, `_techAnalysis`, `_techTankPressures`) and the whole `group('resolveSample', ...)` block from `instrument_tiles_test.dart:234` to the end of `main`. Point the import at the new file:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_sample.dart';
```

Keep the fixture bodies byte-identical to the originals so the assertions still hold. Drop `package:submersion/core/constants/enums.dart` and `_recDive`/`_recDiveNoTemp` if the copied group does not reference them; the analyzer flags unused imports and the build must stay clean.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/instrument_sample_test.dart`

Expected: FAIL at compile time with `Error: Couldn't resolve the package 'submersion' ... instrument_sample.dart` or `Target of URI doesn't exist`.

- [ ] **Step 3: Create the new file**

Create `lib/features/dive_log/presentation/widgets/instrument_sample.dart` and move `InstrumentSample` (currently `instrument_tiles.dart:161-194`) and `resolveSample` (`instrument_tiles.dart:196-238`) into it verbatim, including `resolveSample`'s parameter doc comment about index-aligned curves. Header:

```dart
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

/// Raw (metric, unformatted) instrument values at one review position, and
/// the resolver that reads them out of a profile and its analysis curves.
///
/// Consumed by the fullscreen profile readout and by the Perdix media
/// overlay, which resolves a sample per video frame.
```

- [ ] **Step 4: Delete the moved code from the old file and repoint importers**

In `instrument_tiles.dart`, delete lines 161-238 (`InstrumentSample` and `resolveSample`) and drop the now-unused `profile_position.dart` import if nothing else in the file uses `indexForTimestamp`.

In `perdix_face_resolver.dart:6`, replace

```dart
import 'package:submersion/features/dive_log/presentation/widgets/instrument_tiles.dart';
```

with

```dart
import 'package:submersion/features/dive_log/presentation/widgets/instrument_sample.dart';
```

In `profile_instrument_bar.dart:8`, add the same `instrument_sample.dart` import alongside the existing `instrument_tiles.dart` import (it uses `resolveSample` at line 51 and the tile helpers at 41-57).

- [ ] **Step 5: Remove the moved tests from the old test file**

In `test/features/dive_log/presentation/widgets/instrument_tiles_test.dart`, delete `group('resolveSample', ...)` (line 234 to the closing brace of `main`). Delete any fixture that is now unreferenced there and remove imports the analyzer reports as unused.

- [ ] **Step 6: Run the affected tests**

Run:

```bash
flutter test \
  test/features/dive_log/presentation/widgets/instrument_sample_test.dart \
  test/features/dive_log/presentation/widgets/instrument_tiles_test.dart \
  test/features/media
```

Expected: PASS, with the same total `resolveSample` case count as before the split.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/widgets/instrument_sample.dart \
        lib/features/dive_log/presentation/widgets/instrument_tiles.dart \
        lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart \
        lib/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart \
        test/features/dive_log/presentation/widgets/instrument_sample_test.dart \
        test/features/dive_log/presentation/widgets/instrument_tiles_test.dart
git commit -m "refactor: split instrument sampler out of tile machinery"
```

---

### Task 2: Replace the instrument bar with a transport-only bar

The metric tiles duplicate the draggable readout card that already floats over the chart. Removing them takes the customize sheet, the tile preference helpers, and `ReadoutTile` with them. What remains is a thin container around `ProfileTransportControls`, so the widget stops needing Riverpod entirely.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_transport_bar.dart`
- Delete: `lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart`
- Delete: `lib/features/dive_log/presentation/widgets/instrument_tiles.dart`
- Delete: `lib/features/dive_log/presentation/widgets/readout_tile.dart`
- Delete: `test/features/dive_log/presentation/widgets/instrument_tiles_test.dart`
- Delete: `test/features/dive_log/presentation/widgets/readout_tile_test.dart`
- Delete: `test/features/dive_log/presentation/widgets/profile_instrument_bar_test.dart`
- Create: `test/features/dive_log/presentation/widgets/profile_transport_bar_test.dart`
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:24` (import), `:595-602` (call site)
- Modify: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart:18` (import), `:88-95`, `:376-401`

**Interfaces:**
- Consumes: `instrument_sample.dart` from Task 1 (indirectly; this task removes the last tile-side consumer of `instrument_tiles.dart`).
- Produces: `class ProfileTransportBar extends StatelessWidget` in `lib/features/dive_log/presentation/widgets/profile_transport_bar.dart`, constructor `const ProfileTransportBar({super.key, required String diveId, required List<DiveProfilePoint> profile})`. Note the dropped `analysis` and `tankPressures` parameters: they existed only to feed the tiles.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/profile_transport_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Dive _dive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10, temperature: 20),
  ),
);

void main() {
  Widget wrap(Dive dive) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProfileTransportBar(diveId: dive.id, profile: dive.profile),
      ),
    ),
  );

  testWidgets('renders the playback transport', (tester) async {
    await tester.pumpWidget(wrap(_dive()));
    await tester.pump();

    expect(find.byType(ProfileTransportControls), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('carries no metric tiles and no customize affordance', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(_dive()));
    await tester.pump();

    expect(find.byIcon(Icons.tune), findsNothing);
    expect(find.text('Customize instruments'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_transport_bar_test.dart`

Expected: FAIL at compile time — `profile_transport_bar.dart` does not exist.

- [ ] **Step 3: Create the transport bar**

Create `lib/features/dive_log/presentation/widgets/profile_transport_bar.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';

/// The bottom strip of the fullscreen profile view: playback transport only.
///
/// Phone layouts omit this bar entirely so the chart gets the whole screen
/// (#811). The metric readouts it used to carry duplicated the draggable
/// readout card that floats over the chart.
class ProfileTransportBar extends StatelessWidget {
  final String diveId;

  /// The profile the chart renders; the scrub slider paints its minimap
  /// from these points and seeks within their timestamp range.
  final List<DiveProfilePoint> profile;

  const ProfileTransportBar({
    super.key,
    required this.diveId,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: ProfileTransportControls(diveId: diveId, profile: profile),
    );
  }
}
```

- [ ] **Step 4: Run the new test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/profile_transport_bar_test.dart`

Expected: PASS, both cases.

- [ ] **Step 5: Repoint the fullscreen page**

In `fullscreen_profile_page.dart`, replace the import at line 24

```dart
import 'package:submersion/features/dive_log/presentation/widgets/profile_instrument_bar.dart';
```

with

```dart
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
```

and replace the call site at lines 595-602 with

```dart
                ProfileTransportBar(
                  // The same profile the chart renders: the scrub minimap
                  // and seek range must match what is on screen.
                  diveId: widget.diveId,
                  profile: chartProfile,
                ),
```

- [ ] **Step 6: Delete the dead files**

```bash
git rm lib/features/dive_log/presentation/widgets/profile_instrument_bar.dart \
       lib/features/dive_log/presentation/widgets/instrument_tiles.dart \
       lib/features/dive_log/presentation/widgets/readout_tile.dart \
       test/features/dive_log/presentation/widgets/instrument_tiles_test.dart \
       test/features/dive_log/presentation/widgets/readout_tile_test.dart \
       test/features/dive_log/presentation/widgets/profile_instrument_bar_test.dart
```

`profile_instrument_bar_test.dart` goes entirely: its tile and customize-sheet cases describe deleted behavior, and its transport coverage is already carried by the existing `profile_transport_controls_test.dart` plus the new `profile_transport_bar_test.dart`.

- [ ] **Step 7: Update the fullscreen page test**

In `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`:

Line 18 — swap the import:

```dart
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_bar.dart';
```

Lines 88-95 — rename the case and the type:

```dart
  testWidgets('renders chart and transport bar', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(ProfileTransportBar), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
```

Lines 372-381 and 396-401 — the multi-source case asserts the bar receives the active source's profile. Keep the assertion and its comment, retyped:

```dart
      // The transport bar must scrub against the SAME profile the chart
      // renders: its minimap and seek range are drawn from these points, so
      // passing dive.profile would scrub a different source's timeline.
      expect(
        tester
            .widget<ProfileTransportBar>(find.byType(ProfileTransportBar))
            .profile,
        hasLength(61),
      );
```

and the post-switch assertion with `hasLength(40)`.

- [ ] **Step 8: Run the affected tests**

Run:

```bash
flutter test \
  test/features/dive_log/presentation/widgets/profile_transport_bar_test.dart \
  test/features/dive_log/presentation/widgets/profile_transport_controls_test.dart \
  test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
```

Expected: PASS. `fullscreen_profile_page_test.dart` still runs at the default 800x600 surface, whose `shortestSide` is 600, so the bar renders (the phone gate lands in Task 3).

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A lib/features/dive_log/presentation test/features/dive_log/presentation
git commit -m "refactor: replace instrument bar with transport-only bar"
```

`flutter analyze` at this point will still pass with the settings fields unused — they are plain fields, not flagged. Task 5 removes them.

---

### Task 3: Drop the transport bar on phone widths and tighten chart padding

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:153` (gate), `:362-363` (padding), `:595-600` (conditional bar)
- Modify: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart:56-63` (`_wrap` gains a size), plus new cases

**Interfaces:**
- Consumes: `ProfileTransportBar` from Task 2.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing tests**

In `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`, replace `_wrap` (lines 56-63) with a size-aware version. The explicit `MediaQuery` is what actually drives `MediaQuery.sizeOf` in the page; `setSurfaceSize` alone would not:

```dart
Widget _wrap(List<Override> overrides, {Size? size}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: size == null
        ? const FullscreenProfilePage(diveId: 'd1')
        : MediaQuery(
            data: MediaQueryData(size: size),
            child: const FullscreenProfilePage(diveId: 'd1'),
          ),
  ),
);
```

Note `MaterialApp` loses its `const`. Then add these cases at the end of `main`:

```dart
  const phoneSize = Size(400, 800);
  const desktopSize = Size(1200, 900);

  testWidgets('phone: no transport bar below the chart', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides(), size: phoneSize));
    await tester.pumpAndSettle();

    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(ProfileTransportBar), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('phone in landscape still counts as a phone', (tester) async {
    await tester.pumpWidget(
      _wrap(_defaultOverrides(), size: const Size(800, 400)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileTransportBar), findsNothing);
  });

  testWidgets('desktop: transport bar is present', (tester) async {
    await tester.pumpWidget(_wrap(_defaultOverrides(), size: desktopSize));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileTransportBar), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('phone: playback mode is never activated', (tester) async {
    // ProfileTransportControls.initState is what flips playback mode on.
    // With no transport on phone it never mounts, so the page must leave
    // the shared playback provider untouched.
    final container = ProviderContainer(overrides: _defaultOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(size: phoneSize),
            child: FullscreenProfilePage(diveId: 'd1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(playbackProvider('d1')).isActive, isFalse);
  });

  testWidgets('phone: tapping the chart still drives the readout', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: _defaultOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(size: phoneSize),
            child: FullscreenProfilePage(diveId: 'd1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    chart.onPointSelected!(3);
    await tester.pump();

    expect(container.read(profileReviewProvider('d1')), 30);
  });

  testWidgets('phone: multi-source dive keeps the source bar', (tester) async {
    final now = DateTime(2026, 5, 7);
    DiveDataSource source(String id, String computerId, bool isPrimary) =>
        DiveDataSource(
          id: id,
          diveId: 'd1',
          computerId: computerId,
          isPrimary: isPrimary,
          computerName: isPrimary ? 'Black' : 'Bronze',
          importedAt: now,
          createdAt: now,
        );
    List<DiveProfilePoint> points(int count) => List.generate(
      count,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: 10),
    );

    await tester.pumpWidget(
      _wrap([
        ..._defaultOverrides(),
        diveDataSourcesProvider('d1').overrideWith(
          (ref) async => [
            source('src-a', 'dc-a', true),
            source('src-b', 'dc-b', false),
          ],
        ),
        sourceProfilesProvider('d1').overrideWith(
          (ref) async => {
            'src-a': SourceProfile(
              sourceId: 'src-a',
              computerId: 'dc-a',
              isEdited: false,
              points: points(61),
            ),
            'src-b': SourceProfile(
              sourceId: 'src-b',
              computerId: 'dc-b',
              isEdited: false,
              points: points(40),
            ),
          },
        ),
      ], size: phoneSize),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SourceBar), findsOneWidget);
    expect(find.byType(ProfileTransportBar), findsNothing);
  });
```

The `phoneSize` / `desktopSize` constants must be declared before the first case that uses them; put them at the top of `main`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

Expected: the four phone cases FAIL — `ProfileTransportBar` is still rendered unconditionally, so `findsNothing` fails with "Found 1 widget", and `isActive` is `true`.

- [ ] **Step 3: Add the phone gate**

In `fullscreen_profile_page.dart`, add as the first line of `build` (before `final diveAsync = ...` at line 155):

```dart
    // Phone layouts give the chart the entire screen: no transport strip
    // below it (#811). shortestSide rather than width so a phone held in
    // landscape -- where vertical room is scarcest -- still counts as one.
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
```

- [ ] **Step 4: Apply the gate to padding and the bar**

Replace the chart padding at line 363:

```dart
                        padding: isPhone
                            ? const EdgeInsets.all(4)
                            : const EdgeInsets.fromLTRB(12, 8, 12, 0),
```

Replace the `ProfileTransportBar(...)` call site from Task 2 with:

```dart
                if (!isPhone)
                  ProfileTransportBar(
                    // The same profile the chart renders: the scrub minimap
                    // and seek range must match what is on screen.
                    diveId: widget.diveId,
                    profile: chartProfile,
                  ),
```

Leave the `SourceBar` block at lines 538-594 untouched: source switching stays reachable on phone.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

Expected: PASS, all cases. The pre-existing cases that call `_wrap` with no size still run at the 800x600 default (`shortestSide` 600, not below the threshold), so they keep exercising the desktop layout.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart \
        test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
git commit -m "feat: give the chart the whole screen in fullscreen profile on phone (#811)"
```

---

### Task 4: Escape the app shell and the system bars

Two separate reasons the page is not actually fullscreen. The app uses a single `ShellRoute` whose child Navigator renders inside `MainScaffold`, so a plain `Navigator.of(context).push` leaves the bottom navigation painted underneath. And nothing hides the status bar.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2903-2909`
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:112-121` (initState), `:124-127` (dispose)
- Modify: `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing test**

Immersive mode is observable as a platform-channel call. Add to `fullscreen_profile_page_test.dart`, and add `import 'package:flutter/services.dart';` at the top:

```dart
  testWidgets('enters immersive mode on open and restores it on close', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_wrap(_defaultOverrides()));
    await tester.pumpAndSettle();

    expect(
      calls.where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode'),
      isNotEmpty,
      reason: 'the page must request immersive mode on entry',
    );
    expect(
      calls
          .lastWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .arguments,
      'SystemUiMode.immersiveSticky',
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(
      calls
          .lastWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .arguments,
      'SystemUiMode.edgeToEdge',
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart --plain-name "immersive"`

Expected: FAIL — `Bad state: No element` from `lastWhere`, because the page never calls `setEnabledSystemUIMode`.

- [ ] **Step 3: Add immersive mode to the page**

In `fullscreen_profile_page.dart` `initState`, directly after the existing `SystemChrome.setPreferredOrientations([...])` call (line 112-117), add:

```dart
    // Fullscreen means fullscreen: hide the status and navigation bars so
    // the chart owns the display (#811). Mirrors photo_viewer_page. The
    // call is a no-op on desktop platforms.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
```

In `dispose`, directly after the existing `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` (line 127), add:

```dart
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
```

`package:flutter/services.dart` is already imported at line 2.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

Expected: PASS, all cases including the pre-existing ones.

- [ ] **Step 5: Push the page above the shell**

In `dive_detail_page.dart`, replace `_showFullscreenProfile` (lines 2903-2909) with:

```dart
  void _showFullscreenProfile(BuildContext context, WidgetRef ref, Dive dive) {
    // Root navigator, not the ShellRoute's: pushing on the shell navigator
    // renders the page inside MainScaffold, leaving the bottom navigation
    // bar painted under a supposedly fullscreen chart (#811).
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => FullscreenProfilePage(diveId: dive.id),
      ),
    );
  }
```

There is no automated test for this line. The behavior it changes belongs to Flutter's `Navigator` lookup, and `DiveDetailPage` has no lightweight widget-test harness that stands up a `ShellRoute`. Step 4 of Task 6 verifies it by hand.

- [ ] **Step 6: Run the dive-log test suite**

Run: `flutter test test/features/dive_log`

Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart \
        lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart \
        test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart
git commit -m "feat: fullscreen profile escapes the shell and the system bars (#811)"
```

---

### Task 5: Delete the orphaned tile settings and l10n keys

With the customize sheet gone, `fullscreenTileOrder` and `fullscreenHiddenTiles` have no reader and no writer, and two l10n keys have no call site.

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (lines 84-85, 405-410, 557-558, 715-716, 870-872, 1010-1017, 1058-1059, 1084-1085, 1128-1140, 1778-1787)
- Modify: `lib/l10n/arb/app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Modify: `test/helpers/mock_providers.dart:442-448`
- Modify: `test/features/settings/presentation/providers/settings_notifier_real_test.dart:441-461`
- Modify: `test/features/statistics/presentation/pages/records_page_test.dart:433-439`, `test/features/settings/presentation/pages/settings_page_test.dart:448-454`, `test/features/settings/presentation/pages/settings_page_shared_data_test.dart:521-527`

**Interfaces:**
- Consumes: Task 2's removal of the only reader.
- Produces: `AppSettings` without `fullscreenTileOrder` / `fullscreenHiddenTiles`; `SettingsNotifier` without `setFullscreenTilePreferences`.

- [ ] **Step 1: Delete the settings fields**

In `settings_providers.dart`, remove each of these:

- `SettingsKeys.fullscreenTileOrder` and `SettingsKeys.fullscreenHiddenTiles` (lines 84-85).
- The two `AppSettings` fields with their doc comments (lines 405-410).
- The two constructor defaults (lines 557-558).
- The two `copyWith` parameters (lines 715-716) and their two assignments in the returned `AppSettings` (lines 870-872).
- The two `prefs.getStringList(...)` reads in `_loadSettings` (lines 1014-1017) and the four resulting named arguments (lines 1058-1059 in the no-diver branch, 1084-1085 in the `settings.copyWith` branch).
- Both `prefs.setStringList(...)` calls in `_saveSettings` (lines 1133-1140).
- `setFullscreenTilePreferences` in its entirety (lines 1778-1787).

Do not write a migration to delete the `fullscreen_tile_order` and
`fullscreen_hidden_tiles` entries from existing installs. They are per-device
SharedPreferences string lists, nothing reads them once the keys are gone, and a
migration that touches preferences carries more risk than two orphaned lists.

Two comments referenced these settings by name and must be reworded rather than deleted, because other device-local preferences still sit under them. At line 1010:

```dart
      // Some preferences are device-local (not per-diver), so they're read
      // straight from SharedPreferences rather than the per-diver settings
      // repository.
```

and at line 1129:

```dart
    // Device-local preferences are always persisted to SharedPreferences,
    // independent of whether a diver is currently selected.
```

- [ ] **Step 2: Delete the l10n keys**

Remove `diveLog_instruments_customize` and `diveLog_instruments_customizeHint` from all 11 `.arb` files, along with any `@diveLog_instruments_customize` metadata block in `app_en.arb`. Then regenerate, from the worktree directory:

```bash
flutter gen-l10n
```

Confirm the generated files changed in the worktree and not in the main checkout:

```bash
git status --short lib/l10n
```

- [ ] **Step 3: Update the test helpers**

In `test/helpers/mock_providers.dart`, delete the `setFullscreenTilePreferences` override (lines 442-448). Do the same in `test/features/statistics/presentation/pages/records_page_test.dart`, `test/features/settings/presentation/pages/settings_page_test.dart`, and `test/features/settings/presentation/pages/settings_page_shared_data_test.dart` — each carries its own copy of the same override.

In `test/features/settings/presentation/providers/settings_notifier_real_test.dart`, delete the whole `test('fullscreen tile preferences persist and reload', ...)` block starting at line 441.

- [ ] **Step 4: Run the affected suites**

Run:

```bash
flutter test test/l10n test/features/settings test/features/statistics test/features/dive_log
```

Expected: PASS. `test/l10n/arb_parity_test.dart` in particular confirms the key was removed from every locale, not just English.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add -A lib test
git commit -m "chore: drop unused fullscreen tile preferences and l10n keys"
```

---

### Task 6: Full verification

**Files:** none modified unless a check fails.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: the verified branch.

- [ ] **Step 1: Formatting**

Run: `dart format . && git diff --stat`

Expected: no diff. If `dart format` rewrote anything, commit the reformat before continuing.

- [ ] **Step 2: Analyzer, whole project**

Run: `flutter analyze`

Expected: `No issues found!` and exit code 0. Do not pipe the output — a pipe masks the exit code, and this project treats info-level diagnostics as failures. Watch specifically for unused imports left behind by Tasks 1, 2, and 5.

- [ ] **Step 3: Full test suite**

Run: `flutter test`

Expected: all tests pass. If a suite unrelated to this work fails, re-run that suite alone before assuming this branch caused it; several suites in this project are known to be load-sensitive when run together.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run -d macos`

Only one Flutter instance can run against this project at a time; stop any other running instance first.

Open a dive with a profile, expand the profile to fullscreen, and confirm at a desktop window size:
- the transport row is present below the chart, with play, scrub, elapsed time, and speed chip;
- no metric tile boxes and no tune icon anywhere;
- the chart is unchanged otherwise.

Then narrow the macOS window until its shorter side is under 600 pt and confirm:
- the transport row disappears;
- the chart expands into the freed space;
- dragging across the chart still updates the floating readout card.

On a multi-source dive, confirm the source chips render at both sizes and switching sources still swaps the chart profile.

- [ ] **Step 5: Manual smoke test on a phone**

Run: `flutter run -d <android-device-id>`

Confirm, in fullscreen profile:
- nothing below the chart except the source chips on multi-source dives;
- the app's bottom navigation bar is gone;
- the status bar is hidden, and swiping it back down does not break the layout;
- pressing system back returns to the dive detail page with the bottom navigation and status bar restored.

- [ ] **Step 6: Final commit**

Only if steps 1-5 produced changes:

```bash
dart format .
git add -A
git commit -m "chore: verification fixes for fullscreen profile phone layout"
```
