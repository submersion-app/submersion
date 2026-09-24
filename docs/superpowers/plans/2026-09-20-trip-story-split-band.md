# Trip Story Split Band Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the trip story's two stacked pinned layers (a 180px map and a
52px day header) with one pinned band that docks the day at the start edge and
the map at the end edge, cutting permanent chrome from 232px to 96px.

**Architecture:** A single `SliverPersistentHeader` whose delegate interpolates
the map's width from 100% to 50% against its own `shrinkOffset`, fading a
compact day panel in beside it. Per-day headers become ordinary scrolling
content, and the day the band shows is the one whose heading last crossed a
line a third of the way down the space below the band, with the last visible
day docking once the story is scrolled to its end. The 900px wide-layout
branch is deleted, so one layout serves every width, spanning the full
window. (Both the switch line and the full width were revised after this plan
was executed; see the amendments at the end.)

**Tech Stack:** Flutter, Riverpod, flutter_map, Drift-backed providers,
flutter_test widget tests.

**Spec:** `docs/superpowers/specs/2026-09-20-trip-story-split-band-design.md`

## Global Constraints

- Issue: #2230. The PR body must contain `Closes #2230`.
- No em-dashes anywhere, including code comments and commit messages.
- No tool or model attribution anywhere: no co-author trailers, no
  "generated with" lines, no session URLs, in commit messages, PR titles and
  bodies, issue comments, review comments or review replies.
- No emojis in code, comments or documentation.
- Immutability: never mutate objects or arrays in place.
- Files stay in the 200-400 line range, 800 max.
- Every string shown to a diver comes from l10n, and any new ARB key lands in
  all 11 locales (`ar de en es fr he hu it nl pt zh`).
- Anything displaying units respects the active diver's unit settings. This
  work displays no new units: the docked panel reuses the existing
  `UnitFormatter` calls inside `TripStoryDayHeader`.
- Run `dart format .` after completing any task.
- Tests first, always. A test that has not been seen to fail has not been
  written.

---

## File Structure

**Created:**

- `lib/features/trips/presentation/widgets/story/trip_stat_strip.dart`
  Home for `TripStatStrip`, which currently sits in the map header file by
  accident.
- `lib/features/trips/presentation/widgets/story/trip_story_band_extents.dart`
  Pure value type computing the band's two extents from a `TextScaler`.
- `lib/features/trips/presentation/widgets/story/trip_story_docked_day.dart`
  The tappable docked day panel.
- `lib/features/trips/presentation/widgets/story/trip_story_band.dart`
  The `SliverPersistentHeaderDelegate` that lays the panel and map side by
  side and drives the morph.
- `test/features/trips/presentation/widgets/story/trip_story_band_extents_test.dart`
- `test/features/trips/presentation/widgets/story/trip_story_band_test.dart`
- `test/features/trips/presentation/widgets/story/trip_story_docked_day_test.dart`

**Modified:**

- `lib/features/trips/presentation/widgets/story/trip_story_map_header.dart`
  Loses `TripStatStrip` and the old delegate; keeps `MapCameraAnimator`, the
  map and the fallback. `_StoryMap` is promoted to public `TripStoryMap` so
  the band can hold one instance.
- `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`
  Gains a `compact` flag.
- `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
  Single layout, band wiring, demoted day headers, retimed threshold.
- `lib/l10n/arb/app_*.arb` (11 files): one new key.
- `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
- `test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart`

---

### Task 1: Move TripStatStrip into its own file

A pure move with no behaviour change, done first so later tasks edit a smaller
map header file.

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_stat_strip.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_map_header.dart` (delete `TripStatStrip` and now-unused imports)
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart` (import the new file)
- Modify: `test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart` and `test/features/trips/presentation/widgets/story/trip_story_view_test.dart` (imports)

**Interfaces:**
- Consumes: nothing.
- Produces: `TripStatStrip({Key? key, required TripWithStats stats, int siteCount = 0})` at
  `package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart`.
  Unchanged constructor and behaviour.

- [ ] **Step 1: Create the new file with the class moved verbatim**

Cut the whole `TripStatStrip` class (including its doc comment) out of
`trip_story_map_header.dart` and paste it into the new file with these imports:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
```

- [ ] **Step 2: Update the three importers**

Add to `trip_story_view.dart`, `trip_story_map_header_test.dart` and
`trip_story_view_test.dart`:

```dart
import 'package:submersion/features/trips/presentation/widgets/story/trip_stat_strip.dart';
```

- [ ] **Step 3: Remove imports that only the moved class used**

In `trip_story_map_header.dart`, delete the `unit_formatter.dart`,
`settings_providers.dart` and `trip.dart` imports if nothing else in the file
references them. Let the analyzer decide.

- [ ] **Step 4: Verify nothing broke**

Run: `flutter analyze lib test 2>&1 | tail -5`
Expected: `No issues found!`

Run: `flutter test test/features/trips/presentation/widgets/story/`
Expected: all existing tests pass, unchanged.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/story/
git commit -m "refactor(trips): give the trip stat strip its own file

It lived in the story map header only because that is where it was first
written. The header file is about to grow a band delegate, so move the
strip out before it does."
```

---

### Task 2: Band extents computed from the text scaler

`SliverPersistentHeaderDelegate` needs both extents as numbers known before
layout, which is exactly what `PinnedHeaderSliver` was protecting the day
header from. Computing them from the scaler keeps large text readable.

Note on the numbers: the 96px docked floor has slack, so the computed panel
height only exceeds it above roughly 2.3x text scale. The test therefore proves
growth at 3.0x, not 2.0x.

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_band_extents.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_band_extents_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `TripStoryBandExtents` with `final double docked`, `final double expanded`,
  `const TripStoryBandExtents({required this.docked, required this.expanded})`,
  `factory TripStoryBandExtents.forScaler(TextScaler scaler)`, and the public
  constants `dockedFloor = 96.0`, `expandedFloor = 260.0`,
  `expandedHeadroom = 100.0`. Tasks 4 and 5 both construct it via `forScaler`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';

void main() {
  test('unscaled text gets the floor extents', () {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);

    expect(extents.docked, TripStoryBandExtents.dockedFloor);
    expect(extents.expanded, TripStoryBandExtents.expandedFloor);
  });

  test('large text grows the docked band and the expanded band with it', () {
    final extents = TripStoryBandExtents.forScaler(TextScaler.linear(3.0));

    expect(extents.docked, greaterThan(TripStoryBandExtents.dockedFloor));
    expect(
      extents.expanded,
      extents.docked + TripStoryBandExtents.expandedHeadroom,
    );
  });

  test('the expanded band always clears the docked one', () {
    for (final scale in [1.0, 1.5, 2.0, 3.0, 4.0]) {
      final extents = TripStoryBandExtents.forScaler(TextScaler.linear(scale));

      expect(
        extents.expanded,
        greaterThanOrEqualTo(
          extents.docked + TripStoryBandExtents.expandedHeadroom - 0.01,
        ),
        reason: 'scale $scale left no room to morph',
      );
    }
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_band_extents_test.dart`
Expected: FAIL, `Target of URI doesn't exist: trip_story_band_extents.dart`.

- [ ] **Step 3: Write the implementation**

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The band's two heights, computed rather than hardcoded.
///
/// A [SliverPersistentHeaderDelegate] must report both extents before layout
/// runs, which is the one thing the day header's [PinnedHeaderSliver] was
/// protecting it from: that sliver sizes itself, so scaled accessibility text
/// grew the band instead of being clipped. Deriving both extents from the
/// active [TextScaler] preserves that property inside a fixed-extent sliver.
class TripStoryBandExtents {
  /// Docked height at default text scale. Comfortably clears the panel's two
  /// lines, so it only has to grow above roughly 2.3x scale.
  static const double dockedFloor = 96;

  /// Expanded height at default text scale.
  static const double expandedFloor = 260;

  /// Travel between the two states. Also the minimum, so there is always room
  /// to morph no matter how tall the docked band grows.
  static const double expandedHeadroom = 100;

  /// Title line height factor (titleMedium, 16px) and subtitle (bodySmall,
  /// 12px), plus the band's vertical padding.
  static const double _titleFontSize = 16;
  static const double _subtitleFontSize = 12;
  static const double _titleLineFactor = 1.25;
  static const double _subtitleLineFactor = 1.33;
  static const double _verticalPadding = 12;

  /// Day badge minimum, which floors the panel when the text is tiny.
  static const double _badgeMinimum = 28;

  final double docked;
  final double expanded;

  const TripStoryBandExtents({required this.docked, required this.expanded});

  factory TripStoryBandExtents.forScaler(TextScaler scaler) {
    final lines =
        scaler.scale(_titleFontSize) * _titleLineFactor +
        scaler.scale(_subtitleFontSize) * _subtitleLineFactor;
    final panel = math.max(_badgeMinimum, lines) + _verticalPadding;
    final docked = math.max(dockedFloor, panel);
    return TripStoryBandExtents(
      docked: docked,
      expanded: math.max(expandedFloor, docked + expandedHeadroom),
    );
  }
}
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_band_extents_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/trip_story_band_extents.dart test/features/trips/presentation/widgets/story/trip_story_band_extents_test.dart
git commit -m "feat(trips): compute the story band's extents from the text scaler"
```

---

### Task 3: The compact day header and the docked panel

The panel reuses `TripStoryDayHeader` rather than restating its badge, date,
subtitle and weather logic. The wrapper adds the tap target and the semantics.

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_header.dart`
- Create: `lib/features/trips/presentation/widgets/story/trip_story_docked_day.dart`
- Modify: all 11 of `lib/l10n/arb/app_*.arb`
- Test: `test/features/trips/presentation/widgets/story/trip_story_docked_day_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `TripStoryDayHeader({Key? key, required TripStoryDay day, TripStoryDayWeather? storedWeather, bool compact = false})`.
    When `compact` is true the `Planned` chip is omitted and the band paints no
    background of its own.
  - `TripStoryDockedDay({Key? key, required TripStoryDay day, TripStoryDayWeather? storedWeather, VoidCallback? onTap})`
    at `package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart`.
  - l10n getter `context.l10n.trips_story_dockedDay_goToDay(int number)`.

- [ ] **Step 1: Add the ARB key to English**

In `lib/l10n/arb/app_en.arb`, directly after the `"@trips_story_dayLabel"`
metadata block, insert:

```json
  "trips_story_dockedDay_goToDay": "Go to day {number}",
  "@trips_story_dockedDay_goToDay": {
    "placeholders": {
      "number": {
        "type": "int"
      }
    }
  },
```

- [ ] **Step 2: Add the same key to the other 10 locales**

Insert each line immediately after that file's own `"trips_story_dayLabel"`
line. Only `app_en.arb` is alphabetical, so anchor on the neighbouring key, do
not append. These files carry no `@` metadata blocks.

```
app_ar.arb   "trips_story_dockedDay_goToDay": "الانتقال إلى اليوم {number}",
app_de.arb   "trips_story_dockedDay_goToDay": "Zu Tag {number} springen",
app_es.arb   "trips_story_dockedDay_goToDay": "Ir al día {number}",
app_fr.arb   "trips_story_dockedDay_goToDay": "Aller au jour {number}",
app_he.arb   "trips_story_dockedDay_goToDay": "מעבר ליום {number}",
app_hu.arb   "trips_story_dockedDay_goToDay": "Ugrás a(z) {number}. napra",
app_it.arb   "trips_story_dockedDay_goToDay": "Vai al giorno {number}",
app_nl.arb   "trips_story_dockedDay_goToDay": "Ga naar dag {number}",
app_pt.arb   "trips_story_dockedDay_goToDay": "Ir para o dia {number}",
app_zh.arb   "trips_story_dockedDay_goToDay": "跳转到第 {number} 天",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors. `flutter analyze lib/l10n` reports no issues.

- [ ] **Step 4: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

Future<void> pumpPanel(
  WidgetTester tester,
  TripStoryDay day, {
  VoidCallback? onTap,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 195,
            height: 96,
            child: TripStoryDockedDay(day: day, onTap: onTap),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the day inside a half-width panel without overflowing', (
    tester,
  ) async {
    await pumpPanel(tester, futureDayFixture());

    expect(find.byType(TripStoryDayHeader), findsOneWidget);
    expect(
      tester.widget<TripStoryDayHeader>(find.byType(TripStoryDayHeader)).compact,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a planned day drops the chip in compact form', (tester) async {
    await pumpPanel(tester, futureDayFixture());

    // The chip would consume the subtitle at 195px, and the chapter's own
    // full-width heading still carries it.
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('tapping reports the day', (tester) async {
    var taps = 0;
    await pumpPanel(tester, futureDayFixture(), onTap: () => taps++);

    await tester.tap(find.byType(TripStoryDockedDay));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('the panel is a button for assistive tech', (tester) async {
    await pumpPanel(tester, futureDayFixture(), onTap: () {});

    final semantics = tester.getSemantics(find.byType(TripStoryDockedDay));
    expect(semantics.label, contains('Go to day'));
  });
}
```

The fixture helper builds a planned day. Add it to the same test file above
`main()`:

```dart
TripStoryDay futureDayFixture() => TripStoryDay(
  date: DateTime(2026, 3, 27),
  dayNumber: 3,
  kind: TripStoryDayKind.future,
);
```

- [ ] **Step 5: Run it to make sure it fails**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_docked_day_test.dart`
Expected: FAIL, `trip_story_docked_day.dart` does not exist.

- [ ] **Step 6: Add the compact flag to the day header**

In `trip_story_day_header.dart`, add the field and constructor parameter:

```dart
  /// Compact form for the pinned band's docked panel: no `Planned` chip (it
  /// would consume the subtitle at half width, and the chapter's own
  /// full-width heading still carries it) and no background of its own, since
  /// the band paints one.
  final bool compact;

  const TripStoryDayHeader({
    super.key,
    required this.day,
    this.storedWeather,
    this.compact = false,
  });
```

Then in `build`, make the background transparent and drop the chip:

```dart
    return Material(
      color: compact
          ? Colors.transparent
          : theme.colorScheme.surfaceContainer,
```

and

```dart
              if (!compact && day.kind == TripStoryDayKind.future)
                Chip(
                  label: Text(context.l10n.trips_story_planned),
                  visualDensity: VisualDensity.compact,
                ),
```

- [ ] **Step 7: Write the docked panel**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The day docked at the start edge of the story band.
///
/// It is the compact form of the chapter heading that just scrolled under the
/// band, so it reuses [TripStoryDayHeader] rather than restating the badge,
/// date, subtitle and weather logic. Tapping it scrolls that chapter back into
/// view, mirroring what tapping one of the map's day pins already does.
class TripStoryDockedDay extends StatelessWidget {
  final TripStoryDay day;
  final TripStoryDayWeather? storedWeather;
  final VoidCallback? onTap;

  const TripStoryDockedDay({
    super.key,
    required this.day,
    this.storedWeather,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: context.l10n.trips_story_dockedDay_goToDay(day.dayNumber),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: TripStoryDayHeader(
          day: day,
          storedWeather: storedWeather,
          compact: true,
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Run the tests and make sure they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_docked_day_test.dart test/features/trips/presentation/widgets/story/trip_story_day_header_test.dart`
Expected: PASS. The day header's existing tests must still pass unchanged,
since `compact` defaults to false.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/ lib/l10n/arb/ test/features/trips/presentation/widgets/story/
git commit -m "feat(trips): add the docked day panel for the story band"
```

---

### Task 4: The band delegate

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/trip_story_band.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_map_header.dart` (promote `_StoryMap` to `TripStoryMap`, delete `TripStoryMapHeaderDelegate`)
- Test: `test/features/trips/presentation/widgets/story/trip_story_band_test.dart`
- Modify: `test/features/trips/presentation/widgets/story/trip_story_map_header_test.dart` (drop delegate references)

**Interfaces:**
- Consumes: `TripStoryBandExtents.forScaler` (Task 2), `TripStoryDockedDay` (Task 3).
- Produces:
  - `TripStoryMap({Key? key, required TripStoryMapGeometry geometry, required int activeDayIndex, required MapController mapController, required ValueChanged<int> onDaySelected})`, public, in `trip_story_map_header.dart`.
  - `TripStoryBandDelegate({required TripStoryBandExtents extents, required Widget map, TripStoryDay? dockedDay, TripStoryDayWeather? dockedWeather, VoidCallback? onDockedDayTap})` in `trip_story_band.dart`, plus the public key `TripStoryBandDelegate.bandKey = Key('trip-story-band')`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _bandWidth = 400.0;

Future<void> pumpBand(
  WidgetTester tester, {
  required double shrinkOffset,
  required bool withDay,
  TripStoryDay? day,
}) async {
  final overrides = await getBaseOverrides();
  final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
  final delegate = TripStoryBandDelegate(
    extents: extents,
    map: const SizedBox.expand(key: Key('fake-map')),
    dockedDay: withDay ? (day ?? futureDayFixture()) : null,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: _bandWidth,
            height: extents.expanded,
            child: Builder(
              builder: (context) =>
                  delegate.build(context, shrinkOffset, false),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('expanded, the map takes the full width', (tester) async {
    await pumpBand(tester, shrinkOffset: 0, withDay: true);

    expect(tester.getSize(find.byKey(const Key('fake-map'))).width, _bandWidth);
  });

  testWidgets('docked, the map takes half the width', (tester) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    await pumpBand(
      tester,
      shrinkOffset: extents.expanded - extents.docked,
      withDay: true,
    );

    expect(
      tester.getSize(find.byKey(const Key('fake-map'))).width,
      _bandWidth / 2,
    );
    expect(find.byType(TripStoryDockedDay), findsOneWidget);
  });

  testWidgets('the panel stays hidden through the first half of the morph', (
    tester,
  ) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    await pumpBand(
      tester,
      shrinkOffset: (extents.expanded - extents.docked) * 0.25,
      withDay: true,
    );

    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(TripStoryDockedDay),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 0.0);
  });

  testWidgets('swapping the docked day cross-fades rather than cutting', (
    tester,
  ) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    final docked = extents.expanded - extents.docked;
    await pumpBand(tester, shrinkOffset: docked, withDay: true);

    // Same tree, a different day: the switcher keeps the outgoing panel on
    // screen for the length of the transition.
    await pumpBand(
      tester,
      shrinkOffset: docked,
      withDay: true,
      day: TripStoryDay(
        date: DateTime(2026, 3, 28),
        dayNumber: 4,
        kind: TripStoryDayKind.past,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TripStoryDockedDay), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byType(TripStoryDockedDay), findsOneWidget);
  });

  testWidgets('with no day to dock, the map keeps the full width', (
    tester,
  ) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    await pumpBand(
      tester,
      shrinkOffset: extents.expanded - extents.docked,
      withDay: false,
    );

    expect(tester.getSize(find.byKey(const Key('fake-map'))).width, _bandWidth);
    expect(find.byType(TripStoryDockedDay), findsNothing);
  });
}
```

Add the same fixture helper above `main()` in this file, rather than importing
across test files:

```dart
TripStoryDay futureDayFixture() => TripStoryDay(
  date: DateTime(2026, 3, 27),
  dayNumber: 3,
  kind: TripStoryDayKind.future,
);
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_band_test.dart`
Expected: FAIL, `trip_story_band.dart` does not exist.

- [ ] **Step 3: Promote the map widget to public**

In `trip_story_map_header.dart`, rename `_StoryMap` to `TripStoryMap` and make
its constructor public (`const TripStoryMap({super.key, required ...})`).
Delete `TripStoryMapHeaderDelegate` entirely; the band replaces it. Keep
`MapCameraAnimator` and `_MapFallback`, and have `TripStoryMap` render the
fallback itself when the geometry has no points:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!geometry.hasPoints) return const _MapFallback();
```

- [ ] **Step 4: Write the delegate**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';

/// The story's one pinned layer: the day docked at the start edge, the map at
/// the end edge.
///
/// It replaces two stacked pinned layers (a 180px map plus a 52px day header),
/// which together cost a third of a phone viewport for as long as the diver
/// was reading. The map's width interpolates with [shrinkOffset] rather than
/// snapping, so the split tracks the scroll.
///
/// The [map] is built once by the view and handed in, so a scroll that changes
/// nothing but the shrink offset does not rebuild the map's subtree: only
/// layout re-runs.
class TripStoryBandDelegate extends SliverPersistentHeaderDelegate {
  static const Key bandKey = Key('trip-story-band');

  /// Fraction of the band the map keeps once fully docked.
  static const double dockedMapFraction = 0.5;

  /// The panel fades in over the back half of the morph, so it never sits
  /// half-visible beside a map that is still nearly full width.
  static const double panelFadeStart = 0.5;

  /// Cross-fade between two docked days.
  static const Duration panelSwapDuration = Duration(milliseconds: 200);

  final TripStoryBandExtents extents;
  final Widget map;
  final TripStoryDay? dockedDay;
  final TripStoryDayWeather? dockedWeather;
  final VoidCallback? onDockedDayTap;

  const TripStoryBandDelegate({
    required this.extents,
    required this.map,
    this.dockedDay,
    this.dockedWeather,
    this.onDockedDayTap,
  });

  @override
  double get maxExtent => extents.expanded;

  @override
  double get minExtent => extents.docked;

  @override
  bool shouldRebuild(TripStoryBandDelegate oldDelegate) =>
      oldDelegate.extents.docked != extents.docked ||
      oldDelegate.extents.expanded != extents.expanded ||
      !identical(oldDelegate.map, map) ||
      oldDelegate.dockedDay != dockedDay ||
      oldDelegate.dockedWeather != dockedWeather ||
      oldDelegate.onDockedDayTap != onDockedDayTap;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final span = maxExtent - minExtent;
    final t = span <= 0 ? 1.0 : (shrinkOffset / span).clamp(0.0, 1.0);
    final day = dockedDay;
    // Nothing to dock (a story with no days): the map keeps the whole band
    // rather than leaving half of it blank.
    final mapFraction = day == null
        ? 1.0
        : 1.0 - (1.0 - dockedMapFraction) * t;
    final panelOpacity = day == null
        ? 0.0
        : ((t - panelFadeStart) / (1 - panelFadeStart)).clamp(0.0, 1.0);

    return Material(
      key: bandKey,
      elevation: overlapsContent ? 2 : 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapWidth = constraints.maxWidth * mapFraction;
          final panelWidth = constraints.maxWidth - mapWidth;
          return Row(
            children: [
              // Row lays its first child at the start edge, so this mirrors
              // under RTL without a Directionality check.
              if (day != null && panelWidth > 0)
                SizedBox(
                  width: panelWidth,
                  child: Opacity(
                    opacity: panelOpacity,
                    child: AnimatedSwitcher(
                      duration: panelSwapDuration,
                      // The incoming day rises into the slot, continuing the
                      // upward travel of the full-width heading that just went
                      // under the band, so the swap reads as a hand-off.
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: TripStoryDockedDay(
                        key: ValueKey(day.date),
                        day: day,
                        storedWeather: dockedWeather,
                        onTap: panelOpacity == 1.0 ? onDockedDayTap : null,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: mapWidth,
                child: RepaintBoundary(child: map),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_band_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/ test/features/trips/presentation/widgets/story/
git commit -m "feat(trips): add the story band delegate

The map's width interpolates with the header's shrink offset and the
docked day fades in beside it over the back half of the morph."
```

---

### Task 5: Wire the band into the view and delete the wide branch

> **Superseded in part (2026-09-22).** The centred `_maxContentWidth = 900`
> below was removed: the story spans the full window, and the width test
> asserts that instead. Do not reintroduce the cap. See the amendment at the
> end of this plan.

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

**Interfaces:**
- Consumes: `TripStoryBandDelegate`, `TripStoryBandExtents`, `TripStoryMap`.
- Produces: a view with one `CustomScrollView` at every width, spanning the
  full width it is given, whose first sliver is the pinned band. (As first
  executed it was centred at a 900px maximum; that cap was removed.)

- [ ] **Step 1: Write the failing tests**

Replace the existing `wide layout docks the map beside the story` test with:

```dart
  testWidgets('one band serves every width', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    await pumpView(tester, story, viewSize: const Size(1400, 900));

    expect(find.byKey(const Key('trip-story-wide-layout')), findsNothing);
    expect(find.byKey(TripStoryBandDelegate.bandKey), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('the story does not stretch across a wide window', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 27),
      end: DateTime(2026, 3, 28),
    );
    final story = _story(trip, today: DateTime(2026, 6, 1));
    await pumpView(tester, story, viewSize: const Size(1400, 900));

    expect(
      tester.getSize(find.byType(CustomScrollView)).width,
      lessThanOrEqualTo(900.0),
    );
  });

  testWidgets('the band parks at the docked extent', (tester) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 6; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.getSize(find.byKey(TripStoryBandDelegate.bandKey)).height,
      closeTo(TripStoryBandExtents.dockedFloor, 1.0),
    );
  });
```

Add the imports for `TripStoryBandDelegate` and `TripStoryBandExtents` at the
top of the test file.

- [ ] **Step 2: Run them to make sure they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: FAIL. `TripStoryBandDelegate` is not referenced by the view yet, so
`bandKey` is never found, and the old wide-layout key is still present.

- [ ] **Step 3: Replace the layout**

In `trip_story_view.dart`, delete `_wideBreakpoint` and `_mapHeaderMaxExtent`,
add `const double _maxContentWidth = 900;`, and replace the whole
`LayoutBuilder` in `build` with:

```dart
    final extents = TripStoryBandExtents.forScaler(
      MediaQuery.textScalerOf(context),
    );
    // Built here, not inside the delegate, so a scroll that changes only the
    // shrink offset re-runs layout without rebuilding the map's subtree.
    final map = TripStoryMap(
      geometry: widget.story.mapGeometry,
      activeDayIndex: _activeDayIndex,
      mapController: _mapController,
      onDaySelected: _onPinSelected,
    );
    final days = widget.story.days;
    final dockedDay = days.isEmpty
        ? null
        : days[_activeDayIndex.clamp(0, days.length - 1)];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: TripStoryBandDelegate(
                  extents: extents,
                  map: map,
                  dockedDay: dockedDay,
                  dockedWeather: dockedDay == null
                      ? null
                      : storedWeather[tripDayMillis(dockedDay.date)]
                            ?.toStoryWeather(),
                  onDockedDayTap: dockedDay == null
                      ? null
                      : () => _scrollToDay(_activeDayIndex),
                ),
              ),
              SliverToBoxAdapter(
                child: TripStatStrip(
                  stats: widget.stats,
                  siteCount: _siteCount,
                ),
              ),
              ..._contentSlivers(storedWeather),
            ],
          ),
        ),
      ),
    );
```

Delete `_mapHeaderDelegate()` and the `Row`/`SizedBox(width: 380)` wide branch
entirely.

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: the three new tests PASS. The `day header sticks below the collapsed
map while scrolling` test still FAILS, since day headers are still pinned.
Task 6 replaces it.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/trip_story_view.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git commit -m "feat(trips): put the story behind one pinned band at every width

The 900px branch and its full-height 380px map column are gone; the
story is centered at 900px instead of stretching."
```

---

### Task 6: Demote the day headers and retime the dock

> **Superseded in part (2026-09-23).** The band-edge threshold below read as
> late in the running app and stranded the last days of a trip. The switch
> line is now a third of the way down the space below the band, the last
> visible day docks once the story is scrolled to its end, and a
> `ScrollEndNotification` always resolves. Do not restore the band-edge
> threshold. See the amendment at the end of this plan.

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_view.dart`
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

**Interfaces:**
- Consumes: everything from Task 5.
- Produces: no new API. `_dayKeys[index]` moves from the card column onto
  the chapter heading. The threshold was first executed as
  `viewportTop + extents.docked` and later moved to
  `viewportTop + band + (viewportHeight - band) / 3`.

- [ ] **Step 1: Write the failing tests**

Replace `day header sticks below the collapsed map while scrolling` with:

```dart
  testWidgets('the docked day replaces its full-width heading', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final labels = ['a', 'b', 'c', 'd', 'e', 'f'];
    final story = buildTripStory(
      trip: trip,
      dives: [
        for (var i = 0; i < labels.length; i++)
          _diveAt(
            labels[i],
            DateTime(2026, 3, 25 + i, 9),
            12.10 + i * 0.002,
            -68.20 + i * 0.002,
          ),
      ],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // The band names a day.
    final panel = find.byType(TripStoryDockedDay);
    expect(panel, findsOneWidget);
    final dockedDate = tester
        .widget<TripStoryDockedDay>(panel)
        .day
        .date;

    // No pinned copy of that same heading: nothing sticks below the band.
    final headers = find
        .byWidgetPredicate(
          (w) =>
              w is TripStoryDayHeader && !w.compact && w.day.date == dockedDate,
        )
        .evaluate();
    for (final element in headers) {
      final top = tester
          .getTopLeft(find.byWidget(element.widget))
          .dy;
      expect(
        top,
        lessThan(TripStoryBandExtents.dockedFloor),
        reason: 'a full-width heading is pinned under the band',
      );
    }

    // The first day is well out of view by now.
    expect(find.textContaining('Mar 25'), findsNothing);
  });

  testWidgets('the docked day changes at the band edge, not mid-viewport', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final labels = ['a', 'b', 'c', 'd', 'e', 'f'];
    final story = buildTripStory(
      trip: trip,
      dives: [
        for (var i = 0; i < labels.length; i++)
          _diveAt(
            labels[i],
            DateTime(2026, 3, 25 + i, 9),
            12.10 + i * 0.002,
            -68.20 + i * 0.002,
          ),
      ],
      itineraryDays: [],
      mediaByDiveId: {},
      sightingsByDiveId: {},
      checklistItems: [],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    DateTime dockedDate() => tester
        .widget<TripStoryDockedDay>(find.byType(TripStoryDockedDay))
        .day
        .date;

    // Day 2's heading sits below the band but above the old one-third
    // threshold: under the old timing this scroll would already have changed
    // the docked day.
    final firstDocked = dockedDate();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 150));

    expect(dockedDate(), firstDocked);
  });
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: FAIL. Headers are still pinned, so a full-width copy sits at the
band's bottom edge.

- [ ] **Step 3: Demote the headers**

In `_daySliver`, move the key onto the heading and stop pinning it:

```dart
    // The heading carries _dayKeys[index]: _onScroll and _scrollToDay read
    // positions from it, and the docked panel is resolved from whichever
    // heading has travelled above the band's bottom edge. It is no longer
    // pinned, because the band is now the only pinned layer on the screen.
    final heading = SliverToBoxAdapter(
      child: KeyedSubtree(
        key: _dayKeys[index],
        child: TripStoryDayHeader(
          day: day,
          storedWeather: stored?.toStoryWeather(),
        ),
      ),
    );
    final body = SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [TripStoryDayCard(day: day, tripId: story.trip.id)],
        ),
      ),
    );

    return SliverMainAxisGroup(
      slivers: [
        if (showTodayDivider) divider,
        heading,
        body,
      ],
    );
```

Remove the now-stale `PinnedHeaderSliver` import if nothing else uses it.

- [ ] **Step 4: Retime the threshold**

In `_onScroll`, replace the one-third threshold:

```dart
    // The docked day is the last chapter whose heading has travelled above the
    // band's bottom edge, which is the moment that heading disappears under
    // the band. Resolving earlier (the old viewport/3 threshold) swapped the
    // band's day while the diver could still see the full-width heading in
    // mid-screen, which read as a glitch rather than a hand-off.
    final threshold =
        viewportTop +
        TripStoryBandExtents.forScaler(
          MediaQuery.textScalerOf(context),
        ).docked;
```

Delete the now-unused `viewportHeight` local if nothing else reads it.

- [ ] **Step 5: Run the tests and make sure they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: PASS, including the pre-existing `scrolling resolves the active day
and animates the map` test, which proves the map camera still follows the same
index, and `stat strip scrolls away in the narrow layout`, unchanged.

- [ ] **Step 6: Commit**

```bash
dart format .
git add lib/features/trips/presentation/widgets/story/trip_story_view.dart test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git commit -m "feat(trips): dock the day heading into the band as it scrolls past

Day headings stop being pinned and hand off to the band's panel at its
bottom edge, so only one layer of chrome stays on screen."
```

---

### Task 7: The docked panel scrolls back to its chapter

**Files:**
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`

The wiring landed in Task 5 (`onDockedDayTap`). This task proves it end to end
through the real view, which the panel's own unit test cannot do.

**Interfaces:**
- Consumes: Tasks 5 and 6.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('tapping the docked day scrolls its chapter back into view', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 6; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 3; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final docked = tester
        .widget<TripStoryDockedDay>(find.byType(TripStoryDockedDay))
        .day
        .date;

    await tester.tap(find.byType(TripStoryDockedDay));
    await tester.pumpAndSettle();

    // Its full-width heading is back on screen, below the band.
    final heading = find.byWidgetPredicate(
      (w) => w is TripStoryDayHeader && !w.compact && w.day.date == docked,
    );
    expect(heading, findsOneWidget);
    expect(
      tester.getTopLeft(heading).dy,
      greaterThanOrEqualTo(TripStoryBandExtents.dockedFloor - 1),
    );
  });
```

- [ ] **Step 2: Run it**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: PASS if Task 5's `onDockedDayTap` wiring is correct. If it fails
because the panel is not hit-testable, check that `panelOpacity == 1.0` at the
docked extent, since the delegate passes `onTap: null` below full opacity by
design.

- [ ] **Step 3: Commit**

```bash
git add test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git commit -m "test(trips): cover tapping the docked day to return to its chapter"
```

---

### Task 8: Accessibility, direction and the empty cases

**Files:**
- Test: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
- Modify: `test/features/trips/presentation/widgets/story/trip_story_view_test.dart` (`pumpView` gains a `locale` parameter)

**Interfaces:**
- Consumes: Tasks 5 through 7.
- Produces: `pumpView(..., Locale locale = const Locale('en'))`.

- [ ] **Step 1: Add the locale parameter to pumpView**

```dart
Future<void> pumpView(
  WidgetTester tester,
  TripStory story, {
  List<Override> extra = const [],
  Size viewSize = const Size(800, 2600),
  http.Client? weatherHttpClient,
  Map<int, TripDayWeather>? tripDayWeather,
  Locale locale = const Locale('en'),
}) async {
```

and pass it through to `MaterialApp.router(locale: locale, ...)`.

- [ ] **Step 2: Write the failing tests**

```dart
  testWidgets('the docked day sits at the start edge in both directions', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 6; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );

    Future<double> panelRelativeToMap(Locale locale) async {
      await pumpView(
        tester,
        story,
        viewSize: const Size(500, 700),
        locale: locale,
      );
      final scrollable = find.byType(CustomScrollView);
      for (var i = 0; i < 4; i++) {
        await tester.drag(scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pump(const Duration(milliseconds: 500));
      return tester.getCenter(find.byType(TripStoryDockedDay)).dx -
          tester.getCenter(find.byType(TripStoryMap)).dx;
    }

    expect(await panelRelativeToMap(const Locale('en')), lessThan(0));
    expect(await panelRelativeToMap(const Locale('he')), greaterThan(0));
  });

  testWidgets('large text grows the band instead of clipping the date', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 30),
    );
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 6; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(
      tester,
      story,
      viewSize: const Size(500, 700),
      extra: const [],
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();

    final scrollable = find.byType(CustomScrollView);
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(milliseconds: 500));

    // No RenderFlex overflow from the scaled date and subtitle.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a trip with no mappable points still renders the band', (
    tester,
  ) async {
    final trip = _trip(
      start: DateTime(2026, 3, 25),
      end: DateTime(2026, 3, 27),
    );
    // Dives without sites: the geometry has no points at all.
    final story = _story(
      trip,
      dives: [
        for (var i = 0; i < 3; i++) _dive('d$i', DateTime(2026, 3, 25 + i, 9)),
      ],
      today: DateTime(2026, 6, 1),
    );
    await pumpView(tester, story, viewSize: const Size(500, 700));

    expect(find.byKey(TripStoryBandDelegate.bandKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 3: Run them**

Run: `flutter test test/features/trips/presentation/widgets/story/trip_story_view_test.dart`
Expected: PASS. If the RTL case fails, the delegate is using `left`/`right`
somewhere instead of letting `Row` resolve the start edge.

- [ ] **Step 4: Commit**

```bash
dart format .
git add test/features/trips/presentation/widgets/story/trip_story_view_test.dart
git commit -m "test(trips): cover direction, large text and an empty map in the band"
```

---

### Task 9: Whole-project verification, profile run and PR

**Files:** none changed unless verification finds something.

- [ ] **Step 1: Format the whole project**

Run: `dart format .`
Expected: only files this branch touched are reformatted, if any.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze 2>&1 | tail -20`
Expected: `No issues found!`. Infos are fatal in CI, so treat any as failures.
Do not pipe through `grep`: it masks the exit code.

- [ ] **Step 3: Confirm the generated localizations are not stale**

Run: `flutter gen-l10n && git diff --stat lib/l10n`
Expected: no diff. A diff here means the committed generated hub is stale.

- [ ] **Step 4: Run the full suite once**

Run: `flutter test`
Expected: all green. One full run is sufficient; do not overlap it with another
local test run.

- [ ] **Step 5: Profile the morph on a real Android device**

This is the one check widget tests cannot make: the spec accepts a per-frame
`FlutterMap` relayout, and only a profile run shows what it costs.

Run: `flutter run --profile -d <android-device-id>`

Open a trip with at least six days, scroll the story up and down repeatedly to
drive the band through its full morph, and read worst-frame times off the
DevTools timeline. Record the worst frame in the PR body.

If frames are dropping, apply the escape hatch in order, re-profiling after
each: quantize the interpolated width in `TripStoryBandDelegate.build` to 4px
steps (`final mapWidth = (constraints.maxWidth * mapFraction / 4).roundToDouble() * 4;`),
then 8px, then fall back to a threshold-driven snap dock. Each step is a
separate commit with its measured numbers in the message.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin ericgriffin/trips-map-screen-space-f72bd0
```

PR title: `feat(trips): replace the story's stacked map and day header with one band`

PR body must contain `Closes #2230`, a sentence on the 232px to 96px change,
the note that the map camera now follows the docked day rather than the
one-third threshold, and the worst-frame number from Step 5. No attribution
lines, no session links, no co-author trailers.

---

## Amendment, 2026-09-22

Task 5's centered `_maxContentWidth = 900` was removed after review in the
running app: the gutters either side read as a broken page on desktop. The
story and its band now span the full window, and the width test asserts that
instead. The rest of the plan stands as executed.

## Amendment, 2026-09-23

Task 6's band-edge switch line was moved a third of the way down the space
below the band, after it read as late in the running app and stranded the last
days of a trip. The view also docks the last visible day once the story is
scrolled to its end, and resolves on `ScrollEndNotification` past the throttle.
The spec's docking section records the reasoning.

## Notes for the executor

- This worktree is `ericgriffin/trips-map-screen-space-f72bd0`. Run every
  command from it and do not `cd` to the main checkout.
- If `flutter analyze` reports errors across many unrelated files, the worktree
  was never code-generated. Run `flutter pub get` and the project's codegen
  rather than bypassing the pre-push hook.
- Never use a bare `git stash`: the stash stack is shared with other worktrees.
