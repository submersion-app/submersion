# Calendar Day Matrix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Calendar days" card to Insights > Time Patterns showing dive counts for each of the 366 calendar dates, with coverage, totals, busiest month and day of month, and a tap that opens that date's dives (issue #3127).

**Architecture:** One SQL query groups in-scope dives by wall-clock month and day; a pure immutable `CalendarDayMatrix` derives totals, coverage and busiest values. A new card widget renders the grid with a pinned month column and a horizontally scrolling body. Two new dive query fields (`month`, `day`) let a cell tap open the dive list through the existing `openInsightsDives` path.

**Tech Stack:** Flutter, Riverpod (`FutureProvider`), Drift `customSelect`, the app's query registry, ARB localization (`flutter gen-l10n`), `intl`.

**Spec:** [docs/design/specs/2026-10-28-calendar-day-matrix-design.md](../specs/2026-10-28-calendar-day-matrix-design.md)

## Global Constraints

- Coverage denominator is always 366; 29 February is a valid date; 30-31 February and 31 April, June, September, November are not dates.
- A dive's date is `strftime('%m'|'%d', dive_date_time / 1000, 'unixepoch')` (wall clock flagged as UTC); no timezone conversion.
- Dives in scope: current diver, Insights filter, `DiveStatsScope` via `_diveFilter(filter, alias: 'dives')` with no `gas` or `consumptionRate` flags.
- Card placement: between `_buildSeasonalSection` and `_buildSurfaceIntervalSection`.
- Month row labels come from `insightsMonthLabels(l10n)`; no new month ARB strings.
- Colour: theme primary hue scaled by `count / maxCount`; zero cells a faint neutral (not primary); text switches to `onPrimary` on dark fills; totals bold and uncoloured; busiest totals outlined (all ties).
- Phone and desktop use the same orientation (months as rows); month column pinned, days and totals scroll sideways when they do not fit.
- Every new user-facing string in all 11 ARB files (en, ar, de, es, fr, he, hu, it, nl, pt, zh); plurals use `#`, never a hardcoded digit.
- New files under 800 lines; `insights_repository.dart` untouched except one `part` and one `import` line.
- No em dashes anywhere; `dart format .`; `flutter analyze` clean; `test/architecture/` and `test/shared/` green.

## Review Focus

1. A dive logged late in the evening (23:30) counts on its own date in the matrix AND appears in the list its cell opens (Task 2 and Task 3 tests).
2. A dive on 29 February counts, covers a day and is tappable; 30 February never takes a count, even from a malformed row (Task 1, Task 4).
3. Two months tied for busiest: both outlined and both named in the headline (Task 1, Task 4).
4. Three-digit cell counts and a four-digit grand total render without a RenderFlex overflow at phone width (Task 4).
5. A dark fill (the busiest cell) uses `onPrimary` text so it stays readable in both themes (Task 4).

---

### Task 1: `CalendarDayMatrix` domain value

**Files:**
- Create: `lib/features/insights/domain/calendar_day_matrix.dart`
- Test: `test/features/insights/domain/calendar_day_matrix_test.dart`

**Interfaces:**
- Produces:
  - `typedef CalendarDayCount = ({int month, int day, int count});`
  - `class CalendarDayMatrix` (immutable, `@immutable`), with
    - `factory CalendarDayMatrix.fromCounts(Iterable<CalendarDayCount> rows)` (ignores rows whose date is not valid; sums duplicate dates)
    - `static const CalendarDayMatrix empty`-equivalent: `CalendarDayMatrix.fromCounts(const [])`
    - `static const int calendarDays = 366;`
    - `static bool isValidDate(int month, int day)`
    - `int? count(int month, int day)` (null when not a valid date, else 0 or more)
    - `List<int> get monthTotals` (12, unmodifiable, index 0 = January)
    - `List<int> get dayTotals` (31, unmodifiable, index 0 = day 1)
    - `int get total`, `int get coveredDays`, `double get coverage` (`coveredDays / 366`), `int get maxCount`
    - `List<int> get busiestMonths` (1-based, ascending, empty when total is 0)
    - `List<int> get busiestDays` (1-based, ascending, empty when total is 0)
    - `bool get isEmpty` (`total == 0`)

- [ ] **Step 1: Write the failing tests**

```dart
test('empty input has no dives, no coverage and no busiest values', () {
  final m = CalendarDayMatrix.fromCounts(const []);
  expect(m.isEmpty, isTrue);
  expect(m.total, 0);
  expect(m.coveredDays, 0);
  expect(m.busiestMonths, isEmpty);
  expect(m.busiestDays, isEmpty);
  expect(m.count(5, 6), 0);
});

test('valid and invalid dates', () {
  expect(CalendarDayMatrix.isValidDate(2, 29), isTrue);
  expect(CalendarDayMatrix.isValidDate(2, 30), isFalse);
  for (final month in [4, 6, 9, 11]) {
    expect(CalendarDayMatrix.isValidDate(month, 31), isFalse);
  }
  expect(CalendarDayMatrix.isValidDate(12, 31), isTrue);
  expect(CalendarDayMatrix.isValidDate(13, 1), isFalse);
  expect(CalendarDayMatrix.isValidDate(1, 0), isFalse);
});

test('totals, coverage and max', () {
  final m = CalendarDayMatrix.fromCounts(const [
    (month: 5, day: 6, count: 14),
    (month: 5, day: 7, count: 2),
    (month: 8, day: 6, count: 3),
    (month: 2, day: 29, count: 1),
  ]);
  expect(m.total, 20);
  expect(m.monthTotals[4], 16);
  expect(m.dayTotals[5], 17);
  expect(m.coveredDays, 4);
  expect(m.coverage, closeTo(4 / 366, 1e-9));
  expect(m.maxCount, 14);
  expect(m.count(2, 29), 1);
  expect(m.busiestMonths, [5]);
  expect(m.busiestDays, [6]);
});

test('a row for a date that does not exist is ignored', () {
  final m = CalendarDayMatrix.fromCounts(const [
    (month: 2, day: 30, count: 9),
    (month: 4, day: 31, count: 9),
  ]);
  expect(m.total, 0);
  expect(m.count(2, 30), isNull);
});

test('ties name every busiest month and day', () {
  final m = CalendarDayMatrix.fromCounts(const [
    (month: 5, day: 1, count: 4),
    (month: 8, day: 2, count: 4),
  ]);
  expect(m.busiestMonths, [5, 8]);
  expect(m.busiestDays, [1, 2]);
});

test('the lists cannot be changed from outside', () {
  final m = CalendarDayMatrix.fromCounts(const []);
  expect(() => m.monthTotals[0] = 1, throwsUnsupportedError);
});
```

- [ ] **Step 2: Run** `flutter test test/features/insights/domain/calendar_day_matrix_test.dart`. Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement** `CalendarDayMatrix` in `lib/features/insights/domain/calendar_day_matrix.dart`. Store a 12 x 31 grid of counts (`List<List<int>>`, unmodifiable), compute totals in the factory. Days in month: `[31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]`.

- [ ] **Step 4: Run** the same test. Expected: PASS.

- [ ] **Step 5: Commit** `feat(insights): calendar day matrix value`.

---

### Task 2: Repository query and provider

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_calendar_days.dart` (`part of 'insights_repository.dart';`)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (add `import 'package:submersion/features/insights/domain/calendar_day_matrix.dart';` and `part 'insights_repository_calendar_days.dart';` beside `part 'insights_repository_time_of_day.dart';`)
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart` (provider after `divesBySeasonProvider`)
- Test: `test/features/insights/data/repositories/calendar_day_matrix_query_test.dart`

**Interfaces:**
- Consumes: `CalendarDayMatrix.fromCounts`, `CalendarDayCount` (Task 1).
- Produces:
  - `extension InsightsRepositoryCalendarDays on InsightsRepository { Future<CalendarDayMatrix> getCalendarDayMatrix({String? diverId, DiveFilterState filter = const DiveFilterState()}) }`
  - `final divesByCalendarDayProvider = FutureProvider<CalendarDayMatrix>(...)` using `_keepAliveWithExpiry(ref)`, watching `insightsRepositoryProvider`, `currentDiverIdProvider`, `insightsFilterProvider`.

- [ ] **Step 1: Write the failing tests** (set-up copied from `time_of_day_distribution_test.dart`: `setUpTestDatabase`, a `dive(id, {start, diverId, excluded, maxDepth})` inserter, `DateTime.utc(...)` wall clocks)

```dart
test('counts dives by their logged calendar date', () async {
  await dive('a', start: utc(2019, 5, 6, 9));
  await dive('b', start: utc(2024, 5, 6, 14));
  await dive('c', start: utc(2024, 2, 29, 10));
  final m = await repository.getCalendarDayMatrix();
  expect(m.count(5, 6), 2);
  expect(m.count(2, 29), 1);
  expect(m.total, 3);
});

test('a 23:30 dive stays on its own date', () async {
  await dive('late', start: utc(2025, 5, 6, 23, 30));
  final m = await repository.getCalendarDayMatrix();
  expect(m.count(5, 6), 1);
  expect(m.count(5, 7), 0);
});

test('only the given diver', () async {
  await dive('mine', start: utc(2025, 1, 1), diverId: 'me');
  await dive('theirs', start: utc(2025, 1, 1), diverId: 'them');
  final m = await repository.getCalendarDayMatrix(diverId: 'me');
  expect(m.total, 1);
});

test('dives excluded from statistics are not counted', () async {
  await dive('kept', start: utc(2025, 3, 3));
  await dive('excluded', start: utc(2025, 3, 3), excluded: true);
  expect((await repository.getCalendarDayMatrix()).count(3, 3), 1);
});

test('the Insights filter narrows the count', () async {
  await dive('deep', start: utc(2025, 3, 3), maxDepth: 30);
  await dive('shallow', start: utc(2025, 3, 3), maxDepth: 5);
  final m = await repository.getCalendarDayMatrix(
    filter: const DiveFilterState(minDepth: 20),
  );
  expect(m.count(3, 3), 1);
});
```

- [ ] **Step 2: Run** `flutter test test/features/insights/data/repositories/calendar_day_matrix_query_test.dart`. Expected: FAIL (method not defined).

- [ ] **Step 3: Implement** `getCalendarDayMatrix` following `getDivesBySeason` (diver clause, `_diveFilter(filter, alias: 'dives')`, `GROUP BY month, day`, try/catch logging `'Failed to get dives by calendar day'` and `rethrow`), then the provider.

- [ ] **Step 4: Run** the test. Expected: PASS. Also run `flutter test test/features/insights/presentation/providers/` and, if a provider-enumerating test fails, add `divesByCalendarDayProvider` to it.

- [ ] **Step 5: Commit** `feat(insights): count dives by calendar day`.

---

### Task 3: `month` and `day` query fields and the cell filter

**Files:**
- Modify: `lib/features/dive_log/query/dive_query_entity.dart` (consts beside `_year`; fields after `year`)
- Modify: `lib/l10n/arb/app_*.arb` (all 11: `query_dives_month`, `query_dives_day`, inserted after `query_dives_year`'s neighbours in the same group)
- Regenerate: `lib/features/query/presentation/query_label_lookup.dart` via `python3.14 scripts/gen_query_label_lookup.py`; `flutter gen-l10n`
- Modify: `lib/features/insights/presentation/insights_place_dives.dart`
- Modify: `test/core/query/presentation/query_completions_test.dart`, `test/core/query/fixtures/fixture_registry.dart` only if their enumerations fail
- Test: `test/features/dive_log/query/dive_calendar_fields_test.dart`, `test/features/insights/presentation/insights_place_dives_test.dart`

**Interfaces:**
- Consumes: `getCalendarDayMatrix` (Task 2) in the consistency test.
- Produces:
  - Query fields `month` (`CAST(strftime('%m', {r}.dive_date_time / 1000, 'unixepoch') AS INTEGER)`, `sanity: (min: 1, max: 12)`) and `day` (`'%d'`, `sanity: (min: 1, max: 31)`), both via `_num(..., dimension: FieldDimension.count, emptySql: '{r}.dive_date_time IS NULL')`.
  - `DiveFilterState calendarDayDivesFilter(DiveFilterState scope, {required int month, required int day})`, ANDing `ConditionNode(FieldPath(['month']), QueryOp.eq, NumberValue(month.toDouble(), null))` and the same for `day` onto the scope via the existing `_withPlace`.
  - ARB: `query_dives_month` = "Month", `query_dives_day` = "Day of month".

- [ ] **Step 1: Write the failing tests**

```dart
// dive_calendar_fields_test.dart: compile against the real registry
test('month and day compile to the wall-clock date parts', () {
  final q = compileQuery(
    AndNode([
      ConditionNode(FieldPath(['month']), QueryOp.eq, const NumberValue(5, null)),
      ConditionNode(FieldPath(['day']), QueryOp.eq, const NumberValue(6, null)),
    ]),
    diveQueryEntity,
    appQueryRegistry,
  );
  expect(q.where, contains("strftime('%m'"));
  expect(q.where, contains("strftime('%d'"));
  expect(q.params, [5, 6]);
});

test('out-of-range values are rejected', () {
  // validate `month:13` and `day:32` through the validator used by
  // query_validator_test.dart; expect QueryErrorCode.outOfRange for each,
  // and no error for month:12 and day:31.
});

// insights_place_dives_test.dart, in 'the filters'
test('a calendar day keeps the scope and adds month and day', () {
  final filter = calendarDayDivesFilter(
    const DiveFilterState(minDepth: 20),
    month: 5,
    day: 6,
  );
  expect(filter.minDepth, 20);
  expect(
    filter.query,
    AndNode([
      ConditionNode(FieldPath(const ['month']), QueryOp.eq, const NumberValue(5, null)),
      ConditionNode(FieldPath(const ['day']), QueryOp.eq, const NumberValue(6, null)),
    ]),
  );
});

// insights_place_dives_test.dart, in the database group, using divesOpenedBy
test('a calendar day cell opens exactly the dives it counted', () async {
  // dives on 6 May 2019 09:00, 6 May 2024 23:30, 7 May 2024 00:10,
  // 29 Feb 2024 08:00
  final m = await repository.getCalendarDayMatrix();
  for (final (month, day) in [(5, 6), (5, 7), (2, 29)]) {
    expect(
      await divesOpenedBy(
        calendarDayDivesFilter(const DiveFilterState(), month: month, day: day),
      ),
      m.count(month, day),
      reason: '$month/$day',
    );
  }
});
```

Fill the validator test body in the style of `test/core/query/compiler/query_validator_test.dart` (the exact validator entry point is defined there).

- [ ] **Step 2: Run** both test files. Expected: FAIL (unknown field / undefined function).

- [ ] **Step 3: Implement** the two fields, the ARB keys in all 11 files (translations: de "Monat" / "Tag des Monats", es "Mes" / "Día del mes", fr "Mois" / "Jour du mois", it "Mese" / "Giorno del mese", nl "Maand" / "Dag van de maand", pt "Mês" / "Dia do mês", hu "Hónap" / "A hónap napja", ar "الشهر" / "يوم الشهر", he "חודש" / "יום בחודש", zh "月份" / "日期"), regenerate the lookup and l10n, and add `calendarDayDivesFilter` with a doc comment in the file's style.

- [ ] **Step 4: Run** both test files plus `test/features/query/ test/core/query/ test/features/dive_log/query/ test/features/explore/domain/`. Expected: PASS (update enumerating tests that list field keys if they fail on the two additions).

- [ ] **Step 5: Commit** `feat(dive-log): month and day query fields`.

---

### Task 4: The Calendar days card

**Files:**
- Create: `lib/features/insights/presentation/widgets/calendar_day_matrix_card.dart`
- Modify: `lib/features/insights/presentation/pages/insights_time_patterns_page.dart` (one section between seasonal and surface interval)
- Modify: `lib/l10n/arb/app_*.arb` (all 11, group `insights_timePatterns_calendarDays_*`, inserted after the `insights_timePatterns_seasonal_*` keys)
- Modify: `test/features/insights/presentation/pages/insights_time_patterns_page_test.dart` (override `divesByCalendarDayProvider` in `pumpPage`, default `CalendarDayMatrix.fromCounts(const [])`)
- Test: `test/features/insights/presentation/widgets/calendar_day_matrix_card_test.dart`

**Interfaces:**
- Consumes: `CalendarDayMatrix` (Task 1), `divesByCalendarDayProvider` (Task 2), `calendarDayDivesFilter` (Task 3), `openInsightsDives`, `insightsFilterProvider`, `insightsMonthLabels`, `StatSectionCard`, `StatEmptyState`.
- Produces:
  - `class CalendarDayMatrixCard extends ConsumerWidget` (no parameters; watches `divesByCalendarDayProvider`).
  - `Color calendarCellFill(ColorScheme scheme, int count, int maxCount)` and `Color calendarCellText(ColorScheme scheme, int count, int maxCount)` as top-level functions in the same file (visible for tests).
  - ARB keys (English):
    - `insights_timePatterns_calendarDays_title`: "Calendar days"
    - `insights_timePatterns_calendarDays_subtitle`: "Dives on each date of the year, across all years"
    - `insights_timePatterns_calendarDays_coverage`: "{covered} of {total} calendar days ({percent})" (`covered` int, `total` int, `percent` String)
    - `insights_timePatterns_calendarDays_busiestMonth`: "Busiest month: {months}" (String)
    - `insights_timePatterns_calendarDays_busiestDay`: "Busiest day of month: {days}" (String)
    - `insights_timePatterns_calendarDays_cellSemantics`: "{date}, {count, plural, =0{no dives} one{# dive} other{# dives}}" (`date` String, `count` int)
    - `insights_timePatterns_calendarDays_total`: "Total" (semantics label of the Σ header)
    - `insights_timePatterns_calendarDays_empty`: "No dives to place on the calendar yet"
    - `insights_timePatterns_calendarDays_error`: "Unable to load calendar days"

Behaviour decisions the tests pin:
- Cell size: `((width - monthColumnWidth) / 32).clamp(28.0, 40.0)`; the body (31 day columns + a total column 1.5 cells wide) sits in a horizontal `SingleChildScrollView` beside a fixed month-label column, so on a 360 px phone it scrolls and on a 1200 px window it fits.
- Percent: `NumberFormat.decimalPercentPattern(locale: Localizations.localeOf(context).toLanguageTag(), decimalDigits: 1)`.
- Cell date for semantics: `DateFormat.MMMMd(localeTag).format(DateTime(2024, month, day))` (2024 so 29 February formats).
- Lists of busiest values join with ", ".
- Invalid dates: muted "×", excluded from semantics, not tappable. Valid cells (including 0) are buttons that call `openInsightsDives(context, ref, calendarDayDivesFilter(ref.read(insightsFilterProvider), month: m, day: d))`.
- Busiest outline: `Border.all(color: scheme.tertiary, width: 2)` on the total cells of every busiest month and day.

- [ ] **Step 1: Write the failing tests** (pump `CalendarDayMatrixCard` under `testAppRouter` with a `/dives` stub route, like `insights_geographic_page_test.dart`'s `pumpRouted`, overriding `divesByCalendarDayProvider`)

```dart
testWidgets('headline names coverage and busiest values', (tester) async {
  await pump(tester, matrix([(5, 6, 14), (8, 6, 3), (2, 29, 1)]));
  expect(find.text('3 of 366 calendar days (0.8%)'), findsOneWidget);
  expect(find.text('Busiest month: May'), findsOneWidget);
  expect(find.text('Busiest day of month: 6'), findsOneWidget);
});

testWidgets('ties name every busiest month', (tester) async {
  await pump(tester, matrix([(5, 1, 4), (8, 2, 4)]));
  expect(find.text('Busiest month: May, Aug'), findsOneWidget);
});

testWidgets('cells read as date and count; invalid dates are silent', (tester) async {
  await pump(tester, matrix([(5, 6, 14)]));
  expect(findSemanticsLabelled('May 6, 14 dives'), findsOneWidget);
  expect(findSemanticsLabelled('May 7, no dives'), findsOneWidget);
  expect(findSemanticsLabelled('February 29, no dives'), findsOneWidget);
  expect(findSemanticsLabelled('February 30, no dives'), findsNothing);
});

testWidgets('tapping a cell opens that date under the Insights filter', (tester) async {
  final container = await pump(
    tester,
    matrix([(5, 6, 14)]),
    insightsFilter: const DiveFilterState(minDepth: 18),
  );
  await tester.tap(findSemanticsLabelled('May 6, 14 dives'));
  await tester.pumpAndSettle();
  expect(find.text('dive list'), findsOneWidget);
  final filter = container.read(diveFilterProvider);
  expect(filter.minDepth, 18);
  expect(filter.query, isA<AndNode>());
});

testWidgets('phone width scrolls sideways and keeps month labels', (tester) async {
  await pump(tester, matrix([(5, 31, 120), (8, 1, 1128)]), size: const Size(360, 1400));
  expect(tester.takeException(), isNull); // no overflow with 3-4 digit counts
  expect(find.text('Jan'), findsOneWidget);
  expect(tester.getRect(find.text('31').first).left, greaterThan(360));
  await tester.drag(find.text('15').first, const Offset(-2000, 0));
  await tester.pumpAndSettle();
  expect(tester.getRect(find.text('31').first).right, lessThanOrEqualTo(360));
  expect(tester.getRect(find.text('Jan')).left, greaterThanOrEqualTo(0));
});

testWidgets('empty state', (tester) async {
  await pump(tester, CalendarDayMatrix.fromCounts(const []));
  expect(find.text('No dives to place on the calendar yet'), findsOneWidget);
});

test('zero is neutral, one and max are distinct, dark fill uses onPrimary', () {
  for (final scheme in [
    ColorScheme.fromSeed(seedColor: Colors.blue),
    ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
  ]) {
    final zero = calendarCellFill(scheme, 0, 15);
    final one = calendarCellFill(scheme, 1, 15);
    final max = calendarCellFill(scheme, 15, 15);
    expect(zero, isNot(one));
    expect(one, isNot(max));
    expect(calendarCellText(scheme, 15, 15), scheme.onPrimary);
  }
});
```

In the phone test, `find.text('31').first` is the day-31 column header (header row is built first). `matrix(...)` is a local helper building `CalendarDayMatrix.fromCounts` from `(month, day, count)` tuples.

- [ ] **Step 2: Run** `flutter test test/features/insights/presentation/widgets/calendar_day_matrix_card_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement** the ARB keys in all 11 files (translated, plural with `#`), `flutter gen-l10n`, the card, and the page section. Loading state: `SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))`; empty and error: `StatEmptyState` with `Icons.calendar_month` / `Icons.error_outline`, as `_buildSeasonalSection` does.

- [ ] **Step 4: Run** the card test, `insights_time_patterns_page_test.dart` (with the new override), `test/features/query/presentation/query_labels_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit** `feat(insights): calendar days card on Time Patterns`.

---

### Task 5: Docs and full verification

**Files:**
- Modify: `docs/user/statistics.md` (Time Patterns row at line 101; add "a calendar-day matrix of every date you have dived"; if the page has per-card prose, one short paragraph on reading the grid and tapping a cell)

- [ ] **Step 1:** Update the doc row and paragraph.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze`, `flutter test test/architecture/ test/shared/ test/features/insights/ test/features/query/ test/core/query/ test/features/dive_log/query/ test/features/explore/`. Expected: no analyzer issues, all tests pass.
- [ ] **Step 3:** `git diff origin/main --name-only | xargs grep -nP '\x{2014}'` (the em dash code point) returns nothing.
- [ ] **Step 4: Commit** `docs(insights): calendar days matrix in the user guide`.
