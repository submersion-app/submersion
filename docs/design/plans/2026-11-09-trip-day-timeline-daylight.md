# Trip Day Timeline Daylight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Colour the trip story day card's 24-hour dive bar as a sky (night, sunrise glow, day, sunset glow) and label the real sunrise and sunset times under it.

**Architecture:** A pure domain function computes the day's sun events as fractions of the day (site or 06:00/18:00 fallback) and the gradient stops built from them. A pure presentation helper places the labels under the bar without overlap. `DayRhythmBar` paints the gradient behind outlined dive blocks and lays out the labels as widgets.

**Tech Stack:** Flutter, `CustomPainter` with `LinearGradient` shader, `SunCalculator` / `SiteTimeZone`, `UnitFormatter.formatTime`, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-11-09-trip-day-timeline-daylight-design.md` (issue #4375)

## Global Constraints

- Sun times come from `SunCalculator.wallClockFor` with `SiteTimeZone.wallClockConverterFor`; place = first dive (bar order) whose site location is non-null, not 0,0 and `SunCalculator.isValidCoordinate`.
- Fallback (no usable site, or `wallClockFor` null for the day itself): sunrise at `TimeOfDayClassifier.fallbackSunriseHour` (6), sunset at `fallbackSunsetHour` (18), and no sun times shown or spoken.
- Gradient stops: sunrise = night at -40 min, sunrise glow at 0, day at +30 min; sunset = day at -30 min, sunset glow at 0, night at +40 min. Out-of-range stops are cut off at the bar ends.
- Palette (light / dark): night `#24305A` / `#0D1222`; sunrise glow `#F3A35E` / `#A8622F`; day `#DCEAF6` / `#2F4157`; sunset glow `#EE8A5E` / `#A65236`; sun label `#8A5A1E` / `#E8B871`.
- Every label (sun times and hour ticks) is formatted with `UnitFormatter.formatTime`.
- No schema, settings or classifier change. No em-dashes anywhere. Every ARB string translated in all 11 locales.

## Review Focus

1. A late previous-day sunset that lands after 00:00 (high latitude): the bar must start in dusk/night, not day. Test in Task 1.
2. A day whose first dive has no site but a later dive does: the later site is used. Test in Task 1.
3. Large text scale on a narrow bar: labels must not overprint or throw. Tests in Tasks 2 and 3.
4. A site at 0,0 (the "no fix" stand-in): treated as no location. Test in Task 1.
5. Switching the 12/24-hour setting while the card is shown: labels update without new dives. Test in Task 3.

---

### Task 1: Day daylight model

**Files:**
- Create: `lib/features/trips/domain/services/day_daylight.dart`
- Test: `test/features/trips/domain/services/day_daylight_test.dart`

**Interfaces:**
- Produces:
  - `enum DaylightBasis { site, fallback }`
  - `enum SkyTone { night, sunriseGlow, day, sunsetGlow }`
  - `class SunEvent extends Equatable { final bool isSunrise; final double fraction; final DateTime wallClock; }`
  - `class DayDaylight extends Equatable { final DaylightBasis basis; final bool startsInDaylight; final List<SunEvent> events; SunEvent? get sunrise; SunEvent? get sunset; }` where `events` holds every sunrise and sunset whose wall clock lands on the day, in time order, and `sunrise` / `sunset` are the first of each kind, null when `basis == fallback`.
  - `DayDaylight computeDayDaylight(List<Dive> dives)`
  - `typedef SkyStop = ({double fraction, SkyTone tone});`
  - `List<SkyStop> skyStops(DayDaylight daylight)`: starts with `(0, startsInDaylight ? day : night)`, the three stops per event from Global Constraints (fractions may fall outside 0..1), ends with `(1, tone after the last event)`; fractions are made non-decreasing.

- [ ] **Step 1: Write the failing tests** (Bonaire `GeoPoint(12.15, -68.27)` as in `day_rhythm_layout_test.dart`; all dive times `DateTime.utc`)
  - `uses the site's sunrise and sunset`: Bonaire dive on 2025-03-01 gives `basis == site`, `sunrise.wallClock` within 2 minutes of 06:49, `sunset.wallClock` within 2 minutes of 18:42, `startsInDaylight` false, and `sunrise.fraction` closeTo((6 + 49/60)/24, 0.002).
  - `falls back to 06:00 and 18:00 without a placed site`: a dive with no site gives `basis == fallback`, events at fractions 0.25 and 0.75, `sunrise` and `sunset` null.
  - `treats a 0,0 site as unplaced`: site at `GeoPoint(0, 0)` gives `basis == fallback`.
  - `uses the first dive that has a placed site`: first dive unplaced, second at Bonaire gives `basis == site`.
  - `falls back under polar night`: site `GeoPoint(78.22, 15.65)` (Longyearbyen) on 2025-12-21 gives `basis == fallback`.
  - `starts in daylight after a sunset past midnight`: Tromsø `GeoPoint(69.65, 18.96)` on a mid-May date where the previous day's sunset lands after 00:00 on the site clock (pick the date by printing `SunCalculator.wallClockFor` for 2026-05-10..20 once while writing the test, then hard-code it with a comment): `startsInDaylight` true, first event is a sunset, `sunset.fraction` < 0.1.
  - `skyStops builds three stops per event`: for the fallback day, stops equal `[(0, night), (0.25 - 40/1440, night), (0.25, sunriseGlow), (0.25 + 30/1440, day), (0.75 - 30/1440, day), (0.75, sunsetGlow), (0.75 + 40/1440, night), (1, night)]`.
  - `skyStops are non-decreasing`: for the Tromsø day, every stop's fraction is >= the previous one.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/domain/services/day_daylight_test.dart`
Expected: compile failure, `day_daylight.dart` does not exist.

- [ ] **Step 3: Implement `computeDayDaylight` and `skyStops`**

Day date = calendar date of the chosen dive's `entryTime ?? dateTime`. With a site: resolve the clock once, call `wallClockFor` for date - 1, date, date + 1; null for the date itself means fallback; nulls for the neighbours are skipped. Collect events whose wall clock is in `[dayStart, dayStart + 24h)`, sorted. `startsInDaylight` = the latest neighbour event before `dayStart` is a sunrise; with none, it is true when the first in-day event is a sunset. Fraction = wall-clock offset from `dayStart` in seconds / 86400. Fallback: `startsInDaylight` false, events at 06:00 and 18:00 on the day.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/domain/services/day_daylight_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/domain/services/day_daylight.dart test/features/trips/domain/services/day_daylight_test.dart
git commit -m "feat(trips): compute a day's sun events for the day timeline"
```

### Task 2: Label placement

**Files:**
- Create: `lib/features/trips/presentation/widgets/story/day_rhythm_labels.dart`
- Test: `test/features/trips/presentation/widgets/story/day_rhythm_labels_test.dart`

**Interfaces:**
- Produces:
  - `enum RhythmLabelKind { sunrise, sunset, tick }`
  - `typedef RhythmLabelSpec = ({RhythmLabelKind kind, double centerFraction, double width});`
  - `typedef PlacedRhythmLabel = ({RhythmLabelSpec spec, double left});`
  - `List<PlacedRhythmLabel> placeRhythmLabels(List<RhythmLabelSpec> specs, double barWidth, {double gap = 4})`: places sun labels first (sunrise, then sunset), each centred on `centerFraction * barWidth` and clamped to `[0, barWidth - width]`; a sunset overlapping the sunrise is moved to `sunriseRight + gap`, clamped, and dropped if it still overlaps; ticks are placed last and dropped when they overlap any placed label (with `gap`). Output is in input order minus dropped labels.
  - `class DayRhythmLabelRow extends StatelessWidget` taking `List<({RhythmLabelKind kind, double centerFraction, String text})> labels`, `TextStyle? tickStyle`, `TextStyle? sunStyle`. It measures each label (sun labels include a leading `Icons.wb_twilight` glyph for sunrise and `Icons.nights_stay_outlined` for sunset, sized to the text's font size, 2 px gap) with `TextPainter` under the ambient `TextScaler`, calls `placeRhythmLabels` in a `LayoutBuilder`, and returns a `SizedBox` of the scaled line height containing a `Stack` of `Positioned` labels.

- [ ] **Step 1: Write the failing tests**
  - `centres labels and clamps them inside the bar`: a tick at 0.0 with width 30 on a 300 bar has left 0; a sunrise at 0.5 width 40 has left 130.
  - `drops the midday tick when a sun label covers it`: sunrise at 0.45 width 60 and tick at 0.5 width 30 on 300 returns only the sunrise.
  - `moves the sunset clear of the sunrise`: sunrise at 0.40 width 60 (left 90) and sunset at 0.45 width 60 on 300 give sunset left 154.
  - `drops the sunset when there is no room`: sunrise at 0.9 width 60 and sunset at 0.95 width 60 on 300 return only the sunrise.
  - widget test `shows each label's text`: pumping `DayRhythmLabelRow` with "6:12 AM", "12:00 PM", "6:34 PM" finds each text once.
  - widget test `lays out at a large text scale`: `TextScaler.linear(3)` in a 200 wide box throws no exception.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/day_rhythm_labels_test.dart`
Expected: compile failure.

- [ ] **Step 3: Implement `placeRhythmLabels` and `DayRhythmLabelRow`**

- [ ] **Step 4: Run the tests to verify they pass**

Same command; all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/story/day_rhythm_labels.dart test/features/trips/presentation/widgets/story/day_rhythm_labels_test.dart
git commit -m "feat(trips): place day timeline labels without overlap"
```

### Task 3: Sky bar, outlined blocks, sun labels and semantics

**Files:**
- Modify: `lib/features/trips/presentation/widgets/story/day_rhythm_bar.dart`
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart` (pass `units: units` to `DayRhythmBar` in `_DaySummaryBand`)
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then regenerate with `flutter gen-l10n`
- Test: `test/features/trips/presentation/widgets/story/day_rhythm_bar_test.dart`, `test/features/trips/presentation/widgets/story/trip_story_day_card_test.dart` (add `units` where the bar is built directly, if anywhere)

**Interfaces:**
- Consumes: `computeDayDaylight`, `skyStops`, `SkyTone`, `DaylightBasis` (Task 1); `DayRhythmLabelRow`, `RhythmLabelKind` (Task 2).
- Produces: `DayRhythmBar({required List<Dive> dives, required UnitFormatter units, double trackHeight = 16})`. The bar is a `Column` of the painted track (`trackHeight` tall) and `DayRhythmLabelRow`. The old `height` parameter is replaced by `trackHeight`.

ARB strings (English; translate for ar, de, es, fr, he, hu, it, nl, pt, zh):
- `trips_story_rhythm_semanticsSunriseSunset`: "Dive times during this day. Sunrise {sunrise}, sunset {sunset}." (placeholders `sunrise`, `sunset`, String)
- `trips_story_rhythm_semanticsSunrise`: "Dive times during this day. Sunrise {sunrise}." (placeholder `sunrise`)
- `trips_story_rhythm_semanticsSunset`: "Dive times during this day. Sunset {sunset}." (placeholder `sunset`)

- [ ] **Step 1: Write the failing tests** (in `day_rhythm_bar_test.dart`; update the three existing tests to pass `units: const UnitFormatter(AppSettings())` and use `trackHeight`)
  - `speaks the sun times at a placed site`: Bonaire dive on 2025-03-01 with 24-hour settings; `find.bySemanticsLabel(RegExp(r'^Dive times during this day\. Sunrise 06:4\d, sunset 18:4\d\.$'))` finds one.
  - `keeps the plain label for a fallback day`: unplaced dive; `find.bySemanticsLabel('Dive times during this day')` finds one, and no text matching `RegExp(r'^\d')` other than the 06:00, 12:00 and 18:00 ticks.
  - `labels follow the 12-hour setting`: same Bonaire dive with `AppSettings(timeFormat: TimeFormat.twelveHour)` finds `find.textContaining('AM')` and `find.textContaining('PM')`.
  - `relabels when the time format changes`: pump with 24-hour, then the same dives list with 12-hour units; the 12-hour text is shown.
  - `paints a sky gradient behind the blocks`: the painter (read as `dynamic`, as the existing test does) exposes `stops` equal to `skyStops(computeDayDaylight(dives))`.
  - existing `paints without error at a large text scale and small height`: now `trackHeight: 4` with `TextScaler.linear(6)`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/story/day_rhythm_bar_test.dart`
Expected: compile failure on `units` / `trackHeight`.

- [ ] **Step 3: Implement**

State computes `_blocks` and `_daylight = computeDayDaylight(dives)` when the dives change (as today). `build` derives labels from `_daylight` and `widget.units` on every build, so a settings change relabels. Site basis: sunrise label (if any), midday tick (`units.formatTime(DateTime(2000, 1, 1, 12))`, fraction 0.5), sunset label (if any). Fallback: ticks at 6, 12 and 18 via `formatTime`. Semantics picks the string by which of `sunrise` / `sunset` is non-null (fallback: the existing string). Painter: track `RRect` clipped, filled with a `LinearGradient` whose rect spans from `min(0, firstStop) * width` to `max(1, lastStop) * width` so out-of-range stops are cut off at the ends, colours from a private `_SkyPalette.of(Brightness)` holding the Global Constraints values. Blocks: day `colorScheme.primary`; night `Color.lerp(colorScheme.tertiary, Colors.white, 0.45)` in light, `colorScheme.tertiary` in dark; each block stroked with a 1 px outline, `Colors.white` at 0.85 alpha in light and `Colors.black` at 0.6 alpha in dark. Sun labels use the palette's label colour; ticks keep `labelSmall` in `onSurfaceVariant`. `shouldRepaint` compares stops and palette too.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/presentation/widgets/story/`
Expected: all pass.

- [ ] **Step 5: Format, analyze, architecture guards**

Run: `dart format . && flutter analyze && flutter test test/architecture/ test/features/trips/ test/l10n/`
Expected: no format changes left, no analyzer issues, all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/trips lib/l10n test/features/trips
git commit -m "feat(trips): colour the day timeline for day, night, sunrise and sunset"
```
