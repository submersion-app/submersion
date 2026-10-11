# Connections Timeline Slider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session (the build-feature workflow runs implementation natively, never through subagents). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a two-thumb, day-resolution date range slider beside the Connections Play button, updating the map live while dragged, with Play sweeping the end of the range smoothly to the last dive day.

**Architecture:** A new `ConnectionsTimelineNotifier` replaces `YearPlayNotifier`. It keeps the range on screen (`pending`) apart from the range committed to `connectionsFilterProvider`, and writes the latest `pending` whenever the page reports that the previous graph load has settled. Pure day arithmetic lives in a small domain file. One shared `TimelineControl` widget is used in a card over the canvas and in the panel's Filter tab.

**Tech Stack:** Flutter, Riverpod 3 (`Notifier`, `FutureProvider.autoDispose`, `Provider.autoDispose`), Drift (custom SELECT), `fake_async` for timer tests, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-11-connections-timeline-slider-design.md`

## Global Constraints

- Resolution is whole calendar days; dates are local `DateTime(y, m, d)` with no time of day.
- Day arithmetic uses `DateTime(y, m, d + n)` construction and UTC-date differences, never `add(Duration(days: n))`.
- A range covering the whole span clears `startDate` and `endDate` (no date filter at all).
- Play sweep: the whole first-to-last span takes exactly 20 s (`ConnectionsTimelineNotifier.sweep`), ticking every 16 ms.
- Canvas bar: 12 px margins, full width on phones, capped at 560 px (`ConnectionsTimelineBar.maxWidth`) and left-aligned on wide screens.
- The control hides when the log spans a single day or has no dives.
- Strings: new `connections_timeline_range` ("{start} to {end}", String placeholders) and `connections_timeline_play` ("Play timeline"); keep `connections_yearPlay_pause`; remove `connections_yearRange_label` and `connections_yearPlay_play`. All 11 locales.
- Dates in the label follow the diver's date-format setting through `UnitFormatter.formatDate`.
- No em-dashes anywhere; no mention of AI tooling in code, commits or docs.
- Before committing each task: `dart format .` on touched files, `flutter analyze`, the task's tests.

## Review Focus

1. Span changes while a range is pending (a synced dive, a diver switch): the thumbs should stay inside the new span, not point past it.
2. Pause, then Play again: the sweep should resume from where it paused, not restart from the start thumb.
3. Tapping a thumb without moving it: no filter write and no reload; the timeline returns to idle.
4. Filter dates set in the full filter sheet outside the log's span: the slider shows them clamped, and the filter is not rewritten until the diver drags.
5. Pressing Play with both thumbs on the last dive day: nothing happens (no timer left running).

Each of these has a test in Task 3.

---

## File Structure

| File | Change | Responsibility |
| --- | --- | --- |
| `lib/features/connections/domain/views/timeline_days.dart` | Create | `DayRange` type and pure day arithmetic: `calendarDay`, `dayIndex`, `dayAt`, `clampDays`, `filteredDays`, `filterWithDays` |
| `lib/features/connections/data/repositories/connections_repository.dart` | Modify | `diveYearSpan` becomes `diveDateSpan` |
| `lib/features/connections/presentation/providers/connections_providers.dart` | Modify | `connectionsDateSpanProvider` (and, temporarily, a derived `connectionsYearSpanProvider`) |
| `lib/features/connections/presentation/providers/connections_timeline_provider.dart` | Create | `TimelineState`, `ConnectionsTimelineNotifier`, `connectionsTimelineProvider`, `connectionsTimelineRangeProvider` |
| `lib/features/connections/presentation/widgets/timeline_control.dart` | Create | `TimelinePlayButton`, `TimelineRangeSlider`, `TimelineControl`, `ConnectionsTimelineBar` |
| `lib/features/connections/presentation/pages/connections_page.dart` | Modify | Load reports to the timeline, bar placement, canvas reserve, span readers |
| `lib/features/connections/presentation/pages/connections_graph_stack.dart` | Modify | `playPill` field renamed `timelineBar` |
| `lib/features/connections/presentation/pages/connections_table_area.dart` | Modify | `playPill` field renamed `timelineBar` |
| `lib/features/connections/presentation/panel/filter_tab.dart` | Modify | `TimelineControl` replaces `YearRangeSlider` |
| `lib/features/connections/presentation/widgets/year_play_pill.dart` | Delete | |
| `lib/features/connections/presentation/widgets/year_range_slider.dart` | Delete | |
| `lib/features/connections/presentation/providers/year_play_provider.dart` | Delete | |
| `lib/l10n/arb/app_*.arb` (11) and generated `app_localizations*.dart` | Modify | New keys, then old keys removed |

---

### Task 0: Before screenshots

**Files:** none in the repo; images go to the session scratchpad.

- [ ] **Step 1:** Launch the app on macOS with the `run` skill against the maintainer's dev database, open Connections.
- [ ] **Step 2:** Capture, at desktop width and at phone width (window about 400 px wide): the canvas with the Play pill (`01-connections-canvas-before.png`, `02-connections-canvas-before-phone.png`) and the panel's Filter tab with the year slider (`03-connections-filter-tab-before.png`). Add dark variants of the canvas shots (`...-before-dark.png`).

---

### Task 1: Day arithmetic

**Files:**
- Create: `lib/features/connections/domain/views/timeline_days.dart`
- Test: `test/features/connections/domain/views/timeline_days_test.dart`

**Interfaces:**
- Produces: `typedef DayRange = ({DateTime start, DateTime end});`, `DateTime calendarDay(DateTime)`, `int dayIndex(DateTime from, DateTime to)`, `DateTime dayAt(DateTime from, int days)`, `DayRange clampDays(DayRange range, DayRange span)`, `DayRange filteredDays(DiveFilterState filter, DayRange span)`, `DiveFilterState filterWithDays(DiveFilterState filter, DayRange range, DayRange span)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

void main() {
  final DayRange span = (start: DateTime(2019, 1, 1), end: DateTime(2022, 12, 31));

  test('calendarDay drops the time of day', () {
    expect(calendarDay(DateTime(2020, 5, 6, 23, 59)), DateTime(2020, 5, 6));
  });

  test('dayIndex and dayAt agree across a leap year and a DST change', () {
    expect(dayIndex(DateTime(2019, 1, 1), DateTime(2020, 12, 31)), 730);
    expect(dayAt(DateTime(2019, 1, 1), 730), DateTime(2020, 12, 31));
    // March and late October hold DST changes in most zones that have them.
    expect(dayIndex(DateTime(2024, 3, 1), DateTime(2024, 4, 1)), 31);
    expect(dayAt(DateTime(2024, 3, 1), 31), DateTime(2024, 4, 1));
    expect(dayAt(DateTime(2024, 10, 20), 14), DateTime(2024, 11, 3));
  });

  test('clampDays holds a range inside the span, start never after end', () {
    expect(
      clampDays((start: DateTime(2010), end: DateTime(2030)), span),
      span,
    );
    expect(
      clampDays((start: DateTime(2030), end: DateTime(2010)), span),
      (start: DateTime(2019, 1, 1), end: DateTime(2019, 1, 1)),
    );
    expect(
      clampDays(
        (start: DateTime(2020, 2, 3, 10), end: DateTime(2021, 4, 5, 22)),
        span,
      ),
      (start: DateTime(2020, 2, 3), end: DateTime(2021, 4, 5)),
    );
  });

  test('filteredDays reads a missing date as the span end it stands for', () {
    expect(filteredDays(const DiveFilterState(), span), span);
    expect(
      filteredDays(DiveFilterState(startDate: DateTime(2020, 6, 1)), span),
      (start: DateTime(2020, 6, 1), end: DateTime(2022, 12, 31)),
    );
    expect(
      filteredDays(DiveFilterState(startDate: DateTime(2001)), span),
      span,
    );
  });

  test('filterWithDays clears the dates for the whole span', () {
    final filter = DiveFilterState(
      startDate: DateTime(2020),
      endDate: DateTime(2021),
    );
    final whole = filterWithDays(filter, span, span);
    expect(whole.startDate, isNull);
    expect(whole.endDate, isNull);
  });

  test('filterWithDays writes both days for any narrower range', () {
    final f = filterWithDays(
      const DiveFilterState(),
      (start: DateTime(2019, 1, 1), end: DateTime(2020, 3, 4)),
      span,
    );
    expect(f.startDate, DateTime(2019, 1, 1));
    expect(f.endDate, DateTime(2020, 3, 4));
    final one = filterWithDays(
      const DiveFilterState(),
      (start: DateTime(2021, 7, 7), end: DateTime(2021, 7, 7)),
      span,
    );
    expect(one.startDate, DateTime(2021, 7, 7));
    expect(one.endDate, DateTime(2021, 7, 7));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/connections/domain/views/timeline_days_test.dart`
Expected: FAIL, `timeline_days.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// An inclusive range of calendar days. Both ends are local dates at
/// midnight, the way [DiveFilterState.startDate] and
/// [DiveFilterState.endDate] are read: only the year, month and day count.
typedef DayRange = ({DateTime start, DateTime end});

/// [date] with its time of day dropped.
DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Whole days from [from] to [to]. Counted between UTC dates, so a daylight
/// saving change in between never gains or loses a day.
int dayIndex(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The calendar day [days] after [from], built from its parts: adding a
/// Duration would land an hour off across a daylight saving change.
DateTime dayAt(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);

/// [range] as calendar days held inside [span], start never after end.
DayRange clampDays(DayRange range, DayRange span) {
  DateTime clamp(DateTime date) {
    final day = calendarDay(date);
    if (day.isBefore(span.start)) return span.start;
    if (day.isAfter(span.end)) return span.end;
    return day;
  }

  final start = clamp(range.start);
  final end = clamp(range.end);
  return (start: start.isAfter(end) ? end : start, end: end);
}

/// The days the connections [filter] covers within the log's [span]. No
/// start or end date means the span's own first or last day. The timeline
/// and its play sweep both read the range this way.
DayRange filteredDays(DiveFilterState filter, DayRange span) => clampDays((
  start: filter.startDate ?? span.start,
  end: filter.endDate ?? span.end,
), span);

/// [filter] narrowed to [range]. The whole span is no date filter at all, so
/// its dates are cleared rather than stored as bounds that keep every dive.
DiveFilterState filterWithDays(
  DiveFilterState filter,
  DayRange range,
  DayRange span,
) {
  final days = clampDays(range, span);
  if (!days.start.isAfter(span.start) && !days.end.isBefore(span.end)) {
    return filter.copyWith(clearStartDate: true, clearEndDate: true);
  }
  return filter.copyWith(startDate: days.start, endDate: days.end);
}
```

- [ ] **Step 4: Run it to see it pass**

Run: `flutter test test/features/connections/domain/views/timeline_days_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections/domain/views/timeline_days.dart test/features/connections/domain/views/timeline_days_test.dart
git add lib/features/connections/domain/views/timeline_days.dart test/features/connections/domain/views/timeline_days_test.dart
git commit -m "feat(connections): day arithmetic for the timeline slider"
```

---

### Task 2: Dive date span

**Files:**
- Modify: `lib/features/connections/data/repositories/connections_repository.dart:116-140` (`diveYearSpan`)
- Modify: `lib/features/connections/presentation/providers/connections_providers.dart:68-74`
- Modify: `test/features/connections/data/repositories/connections_repository_test.dart:335-343`
- Modify: `test/features/connections/presentation/providers/connections_providers_test.dart:170-176`
- Modify: `test/architecture/provider_tick_build_smoke_test.dart:234-237`

**Interfaces:**
- Consumes: `DayRange`, `calendarDay` (Task 1).
- Produces: `Future<DayRange?> ConnectionsRepository.diveDateSpan({required String? diverId})`; `connectionsDateSpanProvider` (`FutureProvider.autoDispose<DayRange?>`). `connectionsYearSpanProvider` stays for now, derived from the date span, and is deleted in Task 6.

- [ ] **Step 1: Write the failing tests**

In `connections_repository_test.dart`, replace the `'diveYearSpan and diveIdsFor'` test's first line and add a test after it in the same group:

```dart
    test('diveDateSpan and diveIdsFor', () async {
      expect(await repo.diveDateSpan(diverId: 'me'), (
        start: DateTime(2024, 1, 10),
        end: DateTime(2024, 8, 1),
      ));
      final pair = await repo.diveIdsFor(
        EdgeSelection(_b('jane'), _b('ken')),
        diverId: 'me',
        filter: const DiveFilterState(),
      );
      expect(pair.toSet(), {'d1', 'd2'});
    });

    test('diveDateSpan reads the wall-clock day, late dives included', () async {
      // 23:30 wall clock stays on the 2nd whatever the device's zone.
      await _dive(d, id: 'd10', at: DateTime.utc(2024, 8, 2, 23, 30));
      expect(await repo.diveDateSpan(diverId: 'me'), (
        start: DateTime(2024, 1, 10),
        end: DateTime(2024, 8, 2),
      ));
      expect(await repo.diveDateSpan(diverId: 'nobody'), isNull);
    });
```

(`d` is the `late db.AppDatabase d` that `main`'s `setUp` binds; the fixture's dives run from 2024-01-10 to 2024-08-01, all for diver `me`.)

In `connections_providers_test.dart`, change the `'year span and selection dive ids'` test's span part to:

```dart
  test('date span and selection dive ids', () async {
    final sub1 = c.listen(connectionsDateSpanProvider, (_, _) {});
    addTearDown(sub1.close);
    expect(await c.read(connectionsDateSpanProvider.future), (
      start: DateTime(2024, 1, 10),
      end: DateTime(2024, 1, 10),
    ));
```

(keep the rest of that test unchanged).

In `provider_tick_build_smoke_test.dart`, add beside the year span entry:

```dart
    (
      name: 'connectionsDateSpanProvider',
      read: (c) => c.read(connectionsDateSpanProvider.future),
    ),
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/connections/data/repositories/connections_repository_test.dart test/features/connections/presentation/providers/connections_providers_test.dart`
Expected: compile FAIL, `diveDateSpan` and `connectionsDateSpanProvider` are undefined.

- [ ] **Step 3: Implement**

In `connections_repository.dart`, add `import 'package:submersion/features/connections/domain/views/timeline_days.dart';` and replace `diveYearSpan` with:

```dart
  /// First and last calendar day of the dives in scope, or null when there
  /// are none. Drives the timeline slider.
  Future<DayRange?> diveDateSpan({required String? diverId}) async {
    final scope = diveScopeSql(
      diverId: diverId,
      filter: const DiveFilterState(),
    );
    final rows = await _db
        .customSelect(
          'SELECT MIN(d.dive_date_time) AS first_ms, '
          'MAX(d.dive_date_time) AS last_ms FROM dives d '
          'WHERE ${scope.clauses.join(' AND ')}',
          variables: scope.params.map(Variable.new).toList(),
        )
        .get();
    final first = rows.single.readNullable<int>('first_ms');
    final last = rows.single.readNullable<int>('last_ms');
    if (first == null || last == null) return null;
    return (
      start: calendarDay(wallClockUtcFromMillis(first)),
      end: calendarDay(wallClockUtcFromMillis(last)),
    );
  }
```

In `connections_providers.dart`, add the same import and replace `connectionsYearSpanProvider` with:

```dart
/// First and last calendar day of the log in scope; drives the timeline.
final connectionsDateSpanProvider = FutureProvider.autoDispose<DayRange?>((
  ref,
) async {
  final repository = ref.watch(connectionsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchConnectionsChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  return repository.diveDateSpan(diverId: diverId);
});

/// The years of [connectionsDateSpanProvider], for the year controls until
/// the timeline replaces them.
final connectionsYearSpanProvider =
    FutureProvider.autoDispose<({int first, int last})?>((ref) async {
      final span = await ref.watch(connectionsDateSpanProvider.future);
      return span == null ? null : (first: span.start.year, last: span.end.year);
    });
```

- [ ] **Step 4: Run them to see them pass**

Run: `flutter test test/features/connections/data/repositories/connections_repository_test.dart test/features/connections/presentation/providers/connections_providers_test.dart test/architecture/provider_tick_build_smoke_test.dart test/features/connections/presentation/widgets/`
Expected: PASS (the year widgets still read the derived year provider).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections test/architecture/provider_tick_build_smoke_test.dart
git add lib/features/connections/data/repositories/connections_repository.dart lib/features/connections/presentation/providers/connections_providers.dart test/features/connections/data/repositories/connections_repository_test.dart test/features/connections/presentation/providers/connections_providers_test.dart test/architecture/provider_tick_build_smoke_test.dart
git commit -m "feat(connections): read the log's first and last dive day"
```

---

### Task 3: Timeline notifier

**Files:**
- Create: `lib/features/connections/presentation/providers/connections_timeline_provider.dart`
- Test: `test/features/connections/presentation/providers/connections_timeline_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 helpers; `connectionsDateSpanProvider` (Task 2); `connectionsFilterProvider`; `connectionsViewProvider`.
- Produces:
  - `class TimelineState { DayRange? pending; bool playing; static const idle; }` with value equality.
  - `class ConnectionsTimelineNotifier extends Notifier<TimelineState>` with `static const Duration sweep = Duration(seconds: 20)`, `static const Duration tick = Duration(milliseconds: 16)`, and methods `play()`, `pause()`, `dragStart()`, `dragTo(DayRange)`, `dragEnd(DayRange)`, `loadStarted()`, `loadSettled({required bool failed})`.
  - `connectionsTimelineProvider` (`NotifierProvider.autoDispose<ConnectionsTimelineNotifier, TimelineState>`).
  - `connectionsTimelineRangeProvider` (`Provider.autoDispose<DayRange?>`): the days the slider shows; null when the span is under two days.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/highlight_mode.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_timeline_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/mock_providers.dart';

final DayRange _span = (
  start: DateTime(2019, 1, 1),
  end: DateTime(2022, 12, 31),
);

/// Lets a test move the span, as a synced dive would.
final _spanState = StateProvider<DayRange?>((ref) => _span);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Override> base;
  setUp(() async {
    base = await getBaseOverrides();
  });

  ProviderContainer container({DayRange? span}) {
    final c = ProviderContainer(
      overrides: [
        ...base,
        if (span != null) _spanState.overrideWith((ref) => span),
        connectionsDateSpanProvider.overrideWith(
          (ref) async => ref.watch(_spanState),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(connectionsTimelineProvider, (_, _) {});
    c.listen(connectionsDateSpanProvider, (_, _) {});
    c.listen(connectionsTimelineRangeProvider, (_, _) {});
    return c;
  }

  DiveFilterState filter(ProviderContainer c) =>
      c.read(connectionsFilterProvider);
  TimelineState timeline(ProviderContainer c) =>
      c.read(connectionsTimelineProvider);
  ConnectionsTimelineNotifier notifier(ProviderContainer c) =>
      c.read(connectionsTimelineProvider.notifier);
  void settle(ConnectionsTimelineNotifier n) => n
    ..loadStarted()
    ..loadSettled(failed: false);

  test('from the full span, play starts the end at the start day', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      notifier(c).play();
      expect(timeline(c).playing, isTrue);
      expect(timeline(c).pending, (
        start: DateTime(2019, 1, 1),
        end: DateTime(2019, 1, 1),
      ));
      expect(filter(c).startDate, DateTime(2019, 1, 1));
      expect(filter(c).endDate, DateTime(2019, 1, 1));
      notifier(c).pause();
    });
  });

  test('the sweep crosses the whole span in 20 s, the map following', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c)..play();
      async.elapse(const Duration(seconds: 10));
      expect(timeline(c).pending!.end, DateTime(2020, 12, 31));
      expect(
        filter(c).endDate,
        DateTime(2019, 1, 1),
        reason: 'the first load has not settled',
      );
      settle(n);
      expect(filter(c).endDate, DateTime(2020, 12, 31));
      async.elapse(const Duration(seconds: 10));
      expect(timeline(c).playing, isFalse);
      expect(timeline(c).pending!.end, DateTime(2022, 12, 31));
      settle(n);
      expect(filter(c).startDate, isNull, reason: 'the whole span');
      expect(filter(c).endDate, isNull);
      settle(n);
      expect(timeline(c), TimelineState.idle);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('moves during one load make one write, of the latest range', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final writes = <DiveFilterState>[];
      c.listen(connectionsFilterProvider, (_, next) => writes.add(next));
      final n = notifier(c)..dragStart();
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 2)));
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 3)));
      expect(writes.length, 1);
      expect(
        c.read(connectionsTimelineRangeProvider)!.end,
        DateTime(2020, 6, 3),
        reason: 'the thumbs run ahead of the map',
      );
      settle(n);
      expect(writes.length, 2);
      expect(writes.last.endDate, DateTime(2020, 6, 3));
      n.dragEnd((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 3)));
      settle(n);
      expect(writes.length, 2, reason: 'already on the map');
      expect(timeline(c), TimelineState.idle);
    });
  });

  test('a settle from before the write is not counted', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c)..dragStart();
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)));
      n.loadSettled(failed: false);
      n.dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      expect(filter(c).endDate, DateTime(2020, 6, 1));
      settle(n);
      expect(filter(c).endDate, DateTime(2020, 7, 1));
    });
  });

  test('a load reported during the filter write still counts', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c);
      // A graph that rebuilds synchronously reports its load inside the
      // filter write itself.
      c.listen(connectionsFilterProvider, (_, _) => settle(n));
      n
        ..dragStart()
        ..dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 6, 1)))
        ..dragTo((start: DateTime(2020, 3, 1), end: DateTime(2020, 7, 1)));
      expect(filter(c).endDate, DateTime(2020, 7, 1));
    });
  });

  test('dragging to the whole span clears the dates', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2020),
        endDate: DateTime(2021),
      );
      notifier(c)
        ..dragStart()
        ..dragEnd(_span);
      expect(filter(c).startDate, isNull);
      expect(filter(c).endDate, isNull);
    });
  });

  test('from a range that ends early, play continues from its end', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 6, 30),
      );
      final n = notifier(c)..play();
      expect(timeline(c).pending, (
        start: DateTime(2020, 1, 1),
        end: DateTime(2020, 6, 30),
      ));
      async.elapse(ConnectionsTimelineNotifier.sweep);
      settle(n);
      expect(filter(c).startDate, DateTime(2020, 1, 1));
      expect(filter(c).endDate, DateTime(2022, 12, 31));
    });
  });

  test('an outside filter change stops play and is never overwritten', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c)..play();
      final mine = DiveFilterState(endDate: DateTime(2021, 6, 1));
      c.read(connectionsFilterProvider.notifier).state = mine;
      async.flushMicrotasks();
      expect(timeline(c), TimelineState.idle);
      settle(n);
      async.elapse(const Duration(seconds: 5));
      expect(filter(c), mine);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a view change, a failed load and pause each stop play', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withMode(ConnectionsMode.around));
      async.flushMicrotasks();
      expect(timeline(c).playing, isFalse);

      n.play();
      expect(timeline(c).playing, isTrue);
      n.loadSettled(failed: true);
      expect(timeline(c), TimelineState.idle);

      n
        ..play()
        ..pause();
      expect(timeline(c).playing, isFalse);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('colouring the map does not stop play', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c)..play();
      c
          .read(connectionsViewProvider.notifier)
          .update((v) => v.withHighlight(HighlightMode.groups));
      async.flushMicrotasks();
      expect(timeline(c).playing, isTrue);
      n.pause();
    });
  });

  test('disposing the provider cancels the sweep', () {
    fakeAsync((async) {
      final c = ProviderContainer(
        overrides: [
          ...base,
          connectionsDateSpanProvider.overrideWith((ref) async => _span),
        ],
      );
      addTearDown(c.dispose);
      final keep = c.listen(connectionsTimelineProvider, (_, _) {});
      c.listen(connectionsDateSpanProvider, (_, _) {});
      async.flushMicrotasks();
      c.read(connectionsTimelineProvider.notifier).play();
      final written = c.read(connectionsFilterProvider);
      keep.close();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      expect(c.read(connectionsFilterProvider), written);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('the range follows the filter when idle, clamped for display only', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      expect(c.read(connectionsTimelineRangeProvider), _span);
      final outside = DiveFilterState(
        startDate: DateTime(2010),
        endDate: DateTime(2021, 4, 5),
      );
      c.read(connectionsFilterProvider.notifier).state = outside;
      expect(c.read(connectionsTimelineRangeProvider), (
        start: DateTime(2019, 1, 1),
        end: DateTime(2021, 4, 5),
      ));
      expect(filter(c), outside, reason: 'not rewritten until a drag');
    });
  });

  test('a single-day log has no range and does not play', () {
    fakeAsync((async) {
      final day = DateTime(2022, 5, 5);
      final c = container(span: (start: day, end: day));
      async.flushMicrotasks();
      expect(c.read(connectionsTimelineRangeProvider), isNull);
      notifier(c).play();
      expect(timeline(c), TimelineState.idle);
      expect(filter(c).endDate, isNull);
      expect(async.pendingTimers, isEmpty);
    });
  });

  // Review focus 1.
  test('a span that shrinks keeps the pending range inside it', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      notifier(c)
        ..dragStart()
        ..dragTo((start: DateTime(2022, 6, 1), end: DateTime(2022, 12, 31)));
      c.read(_spanState.notifier).state = (
        start: DateTime(2019, 1, 1),
        end: DateTime(2022, 6, 30),
      );
      async.flushMicrotasks();
      expect(c.read(connectionsTimelineRangeProvider), (
        start: DateTime(2022, 6, 1),
        end: DateTime(2022, 6, 30),
      ));
    });
  });

  // Review focus 2.
  test('pause then play resumes from where the sweep stopped', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final n = notifier(c)..play();
      async.elapse(const Duration(seconds: 10));
      n.pause();
      final paused = timeline(c).pending!.end;
      expect(paused, DateTime(2020, 12, 31));
      n.play();
      expect(timeline(c).pending!.end, paused);
      expect(timeline(c).pending!.start, DateTime(2019, 1, 1));
      n.pause();
    });
  });

  // Review focus 3.
  test('grabbing a thumb and letting go without moving writes nothing', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final writes = <DiveFilterState>[];
      c.listen(connectionsFilterProvider, (_, next) => writes.add(next));
      notifier(c)
        ..dragStart()
        ..dragEnd(_span);
      expect(writes, isEmpty);
      expect(timeline(c), TimelineState.idle);
    });
  });

  // Review focus 5.
  test('play with both thumbs on the last day does nothing', () {
    fakeAsync((async) {
      final c = container();
      async.flushMicrotasks();
      final last = DateTime(2022, 12, 31);
      c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
        startDate: last,
        endDate: last,
      );
      notifier(c).play();
      expect(timeline(c), TimelineState.idle);
      expect(async.pendingTimers, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/connections/presentation/providers/connections_timeline_provider_test.dart`
Expected: compile FAIL, `connections_timeline_provider.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_view_provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// What the timeline shows ahead of the map.
@immutable
class TimelineState {
  const TimelineState({this.pending, this.playing = false});

  static const idle = TimelineState();

  /// The days on screen while a drag or the sweep is ahead of the filter.
  /// Null when idle: the slider then shows the filter's own range.
  final DayRange? pending;

  /// Whether the play sweep is running.
  final bool playing;

  @override
  bool operator ==(Object other) =>
      other is TimelineState &&
      other.pending == pending &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(pending, playing);
}

/// Drives the connections date range from the timeline slider and its play
/// sweep.
///
/// The range on screen ([TimelineState.pending]) runs ahead of the filter:
/// a drag or the sweep moves it every frame, and it is written into the
/// filter only once the page has reported the previous write's graph
/// loaded, latest value wins. A drag across hundreds of days on a large log
/// therefore causes a few reloads, never a queue of them. Any filter change
/// it did not make itself stops it, so it never overwrites what the diver
/// just chose; so does any view change other than the highlight mode.
class ConnectionsTimelineNotifier extends Notifier<TimelineState> {
  /// How long the sweep takes to cross the whole span.
  static const Duration sweep = Duration(seconds: 20);
  static const Duration tick = Duration(milliseconds: 16);

  Timer? _ticker;
  bool _dragging = false;

  /// True from a write until the graph load it caused has settled.
  bool _inFlight = false;

  /// True once a graph load has started since the last write; a load that
  /// settles before then was for the old filter.
  bool _started = false;

  /// The last filter written here, to tell its own writes from the diver's.
  DiveFilterState? _written;

  DateTime _spanStart = DateTime(0);
  DateTime _sweepStart = DateTime(0);
  int _from = 0;
  int _total = 0;

  @override
  TimelineState build() {
    ref.onDispose(_cancel);
    ref.listen<DiveFilterState>(connectionsFilterProvider, (_, next) {
      if (next != _written && (state.playing || state.pending != null)) {
        _reset();
      }
    });
    // Colouring the map is not a change of what it shows: play carries on.
    ref.listen<ConnectionsViewState>(connectionsViewProvider, (prev, next) {
      if (state.playing &&
          prev != null &&
          prev.copyWith(highlight: next.highlight) != next) {
        pause();
      }
    });
    return TimelineState.idle;
  }

  /// Sweeps the end of the range to the log's last day. From the last day
  /// already, the end first jumps back to the start; the start never moves.
  void play() {
    final span = _span();
    if (span == null) return;
    final shown = _shown(span);
    final total = dayIndex(span.start, span.end);
    var from = dayIndex(span.start, shown.end);
    if (from >= total) from = dayIndex(span.start, shown.start);
    if (from >= total) return;
    _cancel();
    _dragging = false;
    _spanStart = span.start;
    _sweepStart = shown.start;
    _from = from;
    _total = total;
    state = TimelineState(
      pending: (start: shown.start, end: dayAt(span.start, from)),
      playing: true,
    );
    _ticker = Timer.periodic(tick, _onTick);
    _commit();
  }

  /// Stops the sweep where it is; the range on screen still reaches the map.
  void pause() {
    _cancel();
    if (state.playing) state = TimelineState(pending: state.pending);
    _commit();
  }

  /// A thumb was grabbed: the sweep stops and the drag owns the range.
  void dragStart() {
    final span = _span();
    if (span == null) return;
    _cancel();
    _dragging = true;
    state = TimelineState(pending: _shown(span));
  }

  void dragTo(DayRange range) {
    final span = _span();
    if (span == null) return;
    state = TimelineState(pending: clampDays(range, span));
    _commit();
  }

  /// The thumb was let go at [range], which always reaches the map.
  void dragEnd(DayRange range) {
    _dragging = false;
    dragTo(range);
  }

  /// The page reports each load of the graph that starts.
  void loadStarted() {
    if (_inFlight) _started = true;
  }

  /// The page reports each settled load of the graph. A failed load stops
  /// everything; the page shows the reload error.
  void loadSettled({required bool failed}) {
    if (failed) {
      if (state.playing || state.pending != null || _inFlight) _reset();
      return;
    }
    if (!_inFlight || !_started) return;
    _inFlight = false;
    _commit();
  }

  /// The log's span, or null when there is nothing to move through.
  DayRange? _span() {
    final span = ref.read(connectionsDateSpanProvider).value;
    return span == null || !span.start.isBefore(span.end) ? null : span;
  }

  DayRange _shown(DayRange span) {
    final pending = state.pending;
    return pending == null
        ? filteredDays(ref.read(connectionsFilterProvider), span)
        : clampDays(pending, span);
  }

  /// Writes the range on screen into the filter, unless a write is still
  /// loading. Once the map shows it and nothing is moving, goes idle.
  void _commit() {
    final pending = state.pending;
    if (pending == null || _inFlight) return;
    final span = _span();
    if (span == null) {
      _reset();
      return;
    }
    final filter = ref.read(connectionsFilterProvider);
    final next = filterWithDays(filter, pending, span);
    if (next == filter) {
      if (!state.playing && !_dragging) state = TimelineState.idle;
      return;
    }
    // Set before the write: a graph that reloads synchronously reports its
    // load during it, and that report must find the write in flight.
    _written = next;
    _inFlight = true;
    _started = false;
    ref.read(connectionsFilterProvider.notifier).state = next;
  }

  void _onTick(Timer timer) {
    // timer.tick counts every period passed, so a late frame catches up
    // rather than slowing the sweep.
    final elapsed = timer.tick * tick.inMicroseconds;
    final day = math.min(
      _total,
      _from + elapsed * _total ~/ sweep.inMicroseconds,
    );
    final done = day >= _total;
    if (done) _cancel();
    state = TimelineState(
      pending: (start: _sweepStart, end: dayAt(_spanStart, day)),
      playing: !done,
    );
    _commit();
  }

  void _reset() {
    _cancel();
    _dragging = false;
    _inFlight = false;
    _started = false;
    state = TimelineState.idle;
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
  }
}

final connectionsTimelineProvider =
    NotifierProvider.autoDispose<ConnectionsTimelineNotifier, TimelineState>(
      ConnectionsTimelineNotifier.new,
    );

/// The days the timeline slider shows: the range ahead of the map while a
/// drag or the sweep runs, else the filter's own, held inside the log's
/// span. Null when the log spans fewer than two days.
final connectionsTimelineRangeProvider = Provider.autoDispose<DayRange?>((
  ref,
) {
  final span = ref.watch(connectionsDateSpanProvider).value;
  if (span == null || !span.start.isBefore(span.end)) return null;
  final pending = ref.watch(
    connectionsTimelineProvider.select((s) => s.pending),
  );
  if (pending != null) return clampDays(pending, span);
  return filteredDays(ref.watch(connectionsFilterProvider), span);
});
```

- [ ] **Step 4: Run it to see it pass**

Run: `flutter test test/features/connections/presentation/providers/connections_timeline_provider_test.dart`
Expected: PASS. If `'the sweep crosses the whole span in 20 s'` is a day off, check that `tick` divides 10 s exactly (16 ms x 625 = 10 s) before changing anything else.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/providers/connections_timeline_provider.dart test/features/connections/presentation/providers/connections_timeline_provider_test.dart
git commit -m "feat(connections): timeline notifier with latest-wins commits and a play sweep"
```

---

### Task 4: New strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other `app_*.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces: `l10n.connections_timeline_play` (String), `l10n.connections_timeline_range(String start, String end)`.

- [ ] **Step 1: Add the keys**

ARB files are feature-grouped. In each file insert `connections_timeline_play` on the line after `connections_yearPlay_pause`, and `connections_timeline_range` plus its `@` entry on the lines after `@connections_yearRange_label`. English:

```json
  "connections_timeline_play": "Play timeline",
```

```json
  "connections_timeline_range": "{start} to {end}",
  "@connections_timeline_range": {"placeholders": {"start": {"type": "String"}, "end": {"type": "String"}}},
```

Translations (the `@` line is identical in every file):

| Locale | `connections_timeline_play` | `connections_timeline_range` |
| --- | --- | --- |
| ar | تشغيل المخطط الزمني | من {start} إلى {end} |
| de | Zeitleiste abspielen | {start} bis {end} |
| es | Reproducir cronología | {start} a {end} |
| fr | Lire la chronologie | Du {start} au {end} |
| he | הפעלת ציר הזמן | {start} עד {end} |
| hu | Idővonal lejátszása | {start} és {end} között |
| it | Riproduci la cronologia | Dal {start} al {end} |
| nl | Tijdlijn afspelen | {start} tot {end} |
| pt | Reproduzir linha do tempo | {start} a {end} |
| zh | 播放时间线 | {start} 至 {end} |

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n && flutter analyze lib/l10n`
Expected: no errors; `app_localizations.dart` declares `String connections_timeline_range(String start, String end);` (placeholder order follows the `@` map: start, then end).

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb
git commit -m "feat(connections): strings for the timeline slider"
```

---

### Task 5: Timeline widgets

**Files:**
- Create: `lib/features/connections/presentation/widgets/timeline_control.dart`
- Test: `test/features/connections/presentation/widgets/timeline_control_test.dart`

**Interfaces:**
- Consumes: Task 1 helpers; Task 3 providers; Task 4 strings; `settingsProvider`, `UnitFormatter`.
- Produces: `TimelinePlayButton` (key `timeline-play-button`), `TimelineRangeSlider` (key `timeline-slider`), `TimelineControl` (label key `timeline-label`), `ConnectionsTimelineBar` (card key `connections-timeline-bar`, `static const double maxWidth = 560`, `static const double reserve = 104`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_timeline_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/timeline_control.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final DayRange _span = (
  start: DateTime(2019, 1, 1),
  end: DateTime(2024, 12, 31),
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  DayRange? span,
  bool noSpan = false,
  DateFormatPreference? dateFormat,
}) async {
  final overrides = await getBaseOverrides(
    settingsNotifier: dateFormat == null
        ? null
        : MockSettingsNotifier(
            AppSettings(
              dateFormat: dateFormat,
              hasAcceptedPlanningDisclaimer: true,
            ),
          ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsDateSpanProvider.overrideWith(
          (ref) async => noSpan ? null : (span ?? _span),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

RangeSlider _slider(WidgetTester tester) =>
    tester.widget<RangeSlider>(find.byKey(const ValueKey('timeline-slider')));

void main() {
  testWidgets('the label shows the range in the diver date format', (
    tester,
  ) async {
    await _pump(tester, const TimelineControl());
    expect(find.text('Jan 1, 2019 to Dec 31, 2024'), findsOneWidget);
    await _pump(
      tester,
      const TimelineControl(),
      dateFormat: DateFormatPreference.dMMMYYYY,
    );
    expect(find.text('1 Jan 2019 to 31 Dec 2024'), findsOneWidget);
  });

  testWidgets('dragging updates the label live and commits the release', (
    tester,
  ) async {
    final c = await _pump(tester, const TimelineControl());
    final slider = _slider(tester);
    expect(slider.values, RangeValues(0, dayIndex(_span.start, _span.end).toDouble()));
    slider.onChangeStart!(slider.values);
    slider.onChanged!(const RangeValues(31, 59));
    await tester.pump();
    expect(find.text('Feb 1, 2019 to Mar 1, 2019'), findsOneWidget);
    expect(c.read(connectionsFilterProvider).endDate, DateTime(2019, 3, 1));

    _slider(tester).onChanged!(const RangeValues(31, 90));
    await tester.pump();
    expect(find.text('Feb 1, 2019 to Apr 1, 2019'), findsOneWidget);
    expect(
      c.read(connectionsFilterProvider).endDate,
      DateTime(2019, 3, 1),
      reason: 'the first range is still loading',
    );
    _slider(tester).onChangeEnd!(const RangeValues(31, 90));
    c.read(connectionsTimelineProvider.notifier)
      ..loadStarted()
      ..loadSettled(failed: false);
    await tester.pump();
    expect(c.read(connectionsFilterProvider).startDate, DateTime(2019, 2, 1));
    expect(c.read(connectionsFilterProvider).endDate, DateTime(2019, 4, 1));
  });

  testWidgets('screen readers hear each thumb as a date', (tester) async {
    await _pump(tester, const TimelineControl());
    expect(_slider(tester).semanticFormatterCallback!(31), 'Feb 1, 2019');
  });

  testWidgets('play and pause toggle, with the tooltip following', (
    tester,
  ) async {
    final c = await _pump(tester, const TimelineControl());
    expect(find.byTooltip('Play timeline'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-play-button')));
    await tester.pump();
    expect(c.read(connectionsTimelineProvider).playing, isTrue);
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-play-button')));
    await tester.pump();
    expect(c.read(connectionsTimelineProvider).playing, isFalse);
    expect(find.byTooltip('Play timeline'), findsOneWidget);
  });

  testWidgets('hidden on a single-day log or with no dives', (tester) async {
    final day = DateTime(2024, 5, 5);
    await _pump(
      tester,
      const ConnectionsTimelineBar(),
      span: (start: day, end: day),
    );
    expect(find.byKey(const ValueKey('connections-timeline-bar')), findsNothing);
    expect(find.byType(RangeSlider), findsNothing);
    await _pump(tester, const ConnectionsTimelineBar(), noSpan: true);
    expect(find.byKey(const ValueKey('connections-timeline-bar')), findsNothing);
  });

  for (final (width, expected) in [(390.0, 366.0), (1280.0, 560.0)]) {
    testWidgets('the bar is $expected wide on a $width-wide canvas', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        const Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ConnectionsTimelineBar(),
            ),
          ],
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('connections-timeline-bar')))
            .width,
        expected,
      );
    });
  }
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/connections/presentation/widgets/timeline_control_test.dart`
Expected: compile FAIL, `timeline_control.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/views/timeline_days.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_timeline_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Play or pause the sweep of the range's end to the last dive day.
class TimelinePlayButton extends ConsumerWidget {
  const TimelinePlayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playing = ref.watch(
      connectionsTimelineProvider.select((s) => s.playing),
    );
    final notifier = ref.read(connectionsTimelineProvider.notifier);
    return IconButton(
      key: const ValueKey('timeline-play-button'),
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      tooltip: playing
          ? l10n.connections_yearPlay_pause
          : l10n.connections_timeline_play,
      onPressed: playing ? notifier.pause : notifier.play,
    );
  }
}

/// Both ends of the date range, by whole day from the log's first dive day
/// to its last. No divisions: thousands of tick marks would smear into a
/// bar, so values are rounded to days here instead.
class TimelineRangeSlider extends ConsumerWidget {
  const TimelineRangeSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final span = ref.watch(connectionsDateSpanProvider).value;
    final range = ref.watch(connectionsTimelineRangeProvider);
    if (span == null || range == null) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    final notifier = ref.read(connectionsTimelineProvider.notifier);
    DayRange days(RangeValues v) => (
      start: dayAt(span.start, v.start.round()),
      end: dayAt(span.start, v.end.round()),
    );
    return RangeSlider(
      key: const ValueKey('timeline-slider'),
      min: 0,
      max: dayIndex(span.start, span.end).toDouble(),
      values: RangeValues(
        dayIndex(span.start, range.start).toDouble(),
        dayIndex(span.start, range.end).toDouble(),
      ),
      semanticFormatterCallback: (v) =>
          units.formatDate(dayAt(span.start, v.round())),
      onChangeStart: (_) => notifier.dragStart(),
      onChanged: (v) => notifier.dragTo(days(v)),
      onChangeEnd: (v) => notifier.dragEnd(days(v)),
    );
  }
}

/// The range in the diver's date format above Play and the slider. Shared
/// by the bar over the canvas and the panel's Filter tab, so the two always
/// show the same thumbs. Hidden when the log spans fewer than two days.
class TimelineControl extends ConsumerWidget {
  const TimelineControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(connectionsTimelineRangeProvider);
    if (range == null) return const SizedBox.shrink();
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 12, top: 8),
          child: Text(
            context.l10n.connections_timeline_range(
              units.formatDate(range.start),
              units.formatDate(range.end),
            ),
            key: const ValueKey('timeline-label'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Row(
          children: [
            TimelinePlayButton(),
            Expanded(child: TimelineRangeSlider()),
          ],
        ),
      ],
    );
  }
}

/// [TimelineControl] in a card over the canvas: as wide as the canvas on a
/// phone, at most [maxWidth] and at the start edge on a wide screen. Place
/// it with a Positioned spanning the canvas width; the space beside a capped
/// card lets taps through to the canvas.
class ConnectionsTimelineBar extends ConsumerWidget {
  const ConnectionsTimelineBar({super.key});

  static const double maxWidth = 560;

  /// Room the canvas keeps clear at its bottom edge for the bar.
  static const double reserve = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(connectionsTimelineRangeProvider) == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: const Card(
          key: ValueKey('connections-timeline-bar'),
          margin: EdgeInsets.zero,
          child: TimelineControl(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to see it pass**

Run: `flutter test test/features/connections/presentation/widgets/timeline_control_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/connections test/features/connections
git add lib/features/connections/presentation/widgets/timeline_control.dart test/features/connections/presentation/widgets/timeline_control_test.dart
git commit -m "feat(connections): timeline control, slider and canvas bar"
```

---

### Task 6: Wire the timeline in and retire year play

**Files:**
- Modify: `lib/features/connections/presentation/pages/connections_page.dart` (imports; lines ~251-256 share caption span; ~345-357 load reports and keep-alive; ~405-416 bar and reserve; ~444 empty state)
- Modify: `lib/features/connections/presentation/pages/connections_graph_stack.dart` (`playPill` field and use, rename to `timelineBar`)
- Modify: `lib/features/connections/presentation/pages/connections_table_area.dart` (same rename)
- Modify: `lib/features/connections/presentation/panel/filter_tab.dart`
- Modify: `lib/features/connections/presentation/providers/connections_providers.dart` (delete `connectionsYearSpanProvider`)
- Delete: `lib/features/connections/presentation/widgets/year_play_pill.dart`, `lib/features/connections/presentation/widgets/year_range_slider.dart`, `lib/features/connections/presentation/providers/year_play_provider.dart`, and their tests `test/features/connections/presentation/widgets/year_play_pill_test.dart`, `test/features/connections/presentation/widgets/year_range_slider_test.dart`, `test/features/connections/presentation/providers/year_play_provider_test.dart`
- Modify: `lib/l10n/arb/app_*.arb` (remove `connections_yearPlay_play`, `connections_yearRange_label`, `@connections_yearRange_label`), regenerate
- Modify tests: `test/features/connections/presentation/pages/connections_page_test.dart` (override at ~86; tests at ~660-686 and ~750-776), `test/features/connections/presentation/pages/connections_page_display_test.dart` (override ~83; expectation ~195), `test/features/connections/presentation/panel/connections_panel_test.dart` (override ~37), `test/architecture/provider_tick_build_smoke_test.dart` (remove the year span entry)

**Interfaces:**
- Consumes: everything from Tasks 1 to 5.

- [ ] **Step 1: Update the tests first**

In all three page/panel test files, replace the year span override with:

```dart
        connectionsDateSpanProvider.overrideWith(
          (ref) async => (start: DateTime(2019, 1, 1), end: DateTime(2024, 12, 31)),
        ),
```

In `connections_page_display_test.dart` replace `expect(find.byType(YearPlayPill), findsOneWidget);` with `expect(find.byType(ConnectionsTimelineBar), findsOneWidget);` and swap the import for `timeline_control.dart`.

In `connections_page_test.dart` replace the play pill test with:

```dart
  testWidgets('the timeline bar sits on the canvas and a load moves play on', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: _phone,
      // Like the real provider, the graph reloads when the filter changes;
      // the timeline writes its next range only after that reload.
      graph: (ref, budget) {
        ref.watch(connectionsFilterProvider);
        return _graph;
      },
    );
    expect(find.byKey(const ValueKey('connections-timeline-bar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-play-button')));
    await tester.pump();
    expect(c.read(connectionsTimelineProvider).playing, isTrue);
    expect(c.read(connectionsFilterProvider).endDate, DateTime(2019, 1, 1));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      c.read(connectionsFilterProvider).endDate!.isAfter(DateTime(2019, 6, 1)),
      isTrue,
      reason: 'loads settled and the sweep moved on about 219 days',
    );
    c.read(connectionsTimelineProvider.notifier).pause();
    await tester.pump(const Duration(milliseconds: 100));
  });
```

and the empty-year test with:

```dart
  testWidgets('play carries on through a range with an empty map', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      size: _phone,
      graph: (ref, budget) {
        final end = ref.watch(connectionsFilterProvider).endDate;
        return end != null && end.isBefore(DateTime(2019, 2, 1))
            ? ConnectionGraph.empty
            : _graph;
      },
    );
    await tester.tap(find.byKey(const ValueKey('timeline-play-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('connections-timeline-bar')),
      findsOneWidget,
      reason: 'the bar stays over the empty state so play can be paused',
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.read(connectionsTimelineProvider).playing, isTrue);
    expect(
      c.read(connectionsFilterProvider).endDate!.isAfter(DateTime(2019, 2, 1)),
      isTrue,
    );
    c.read(connectionsTimelineProvider.notifier).pause();
    await tester.pump(const Duration(milliseconds: 100));
  });
```

Swap the test file's `year_play_provider.dart` import for `connections_timeline_provider.dart`. In `provider_tick_build_smoke_test.dart` delete the `connectionsYearSpanProvider` entry. Delete the three year test files with `git rm`.

- [ ] **Step 2: Run the page tests to see them fail**

Run: `flutter test test/features/connections/presentation/pages/`
Expected: FAIL, no `connections-timeline-bar` on the page.

- [ ] **Step 3: Wire the page**

In `connections_page.dart`:

1. Imports: remove `year_play_pill.dart` and `year_play_provider.dart`; add `connections_timeline_provider.dart` and `widgets/timeline_control.dart`.
2. Share caption (in `_share`), keeping the caption's year API:

```dart
      span: switch (ref.read(connectionsDateSpanProvider).value) {
        null => null,
        final s => (first: s.start.year, last: s.end.year),
      },
```

3. In `build`, the graph listener's report block becomes:

```dart
      // The timeline writes its next range only once the last has loaded.
      final timeline = ref.read(connectionsTimelineProvider.notifier);
      if (next.isLoading) {
        timeline.loadStarted();
      } else {
        timeline.loadSettled(failed: next.hasError);
      }
```

and the keep-alive becomes:

```dart
    // The timeline lives as long as the page, not only while its bar shows:
    // an empty range swaps the canvas out, and play must carry on past it.
    ref.listen<TimelineState>(connectionsTimelineProvider, (_, _) {});
```

4. After `final layoutChoice = ...`, add (select keeps the page from rebuilding on every sweep tick):

```dart
    final timelineInset =
        ref.watch(connectionsTimelineRangeProvider.select((r) => r != null))
        ? ConnectionsTimelineBar.reserve
        : 0.0;
```

5. In `canvasArea`, replace the `playPill` declaration with:

```dart
      // Shown over the canvas, the tables and an empty played range alike.
      final timelineBar = Positioned(
        left: 12,
        right: 12,
        bottom: bottomInset + 12,
        child: const ConnectionsTimelineBar(),
      );
```

and use `timelineBar` wherever `playPill` was used (the empty-state Stack, `ConnectionsTableArea(... timelineBar: timelineBar)`, `ConnectionsGraphStack(... timelineBar: timelineBar)`). Pass `bottomInset: bottomInset + timelineInset` to both `ConnectionsTableArea` and `ConnectionsGraphStack`, so the camera fit and the table's last rows stay clear of the bar.

6. Empty state: `hasAnyDives: ref.watch(connectionsDateSpanProvider).value != null,`.

In `connections_graph_stack.dart` and `connections_table_area.dart`, rename the `playPill` constructor parameter and field to `timelineBar` (keep type `Widget`).

In `filter_tab.dart`, swap the import for `widgets/timeline_control.dart`, replace `const YearRangeSlider(),` with `const TimelineControl(),`, and change the class doc's first word "Years," to "The timeline,".

In `connections_providers.dart`, delete `connectionsYearSpanProvider`. Delete the three year source files with `git rm`.

- [ ] **Step 4: Remove the old strings**

From each of the 11 ARB files delete the `connections_yearPlay_play`, `connections_yearRange_label` and `@connections_yearRange_label` lines (keep `connections_yearPlay_pause`). Run `flutter gen-l10n`.

- [ ] **Step 5: Run everything touched**

Run: `grep -rn "yearPlay\|YearPlay\|YearRange\|yearRange_label\|connectionsYearSpanProvider\|filteredYears\|playPill" lib test` (expected: only `connections_yearPlay_pause` hits)
Run: `flutter analyze`
Run: `flutter test test/features/connections test/architecture`
Expected: analyze clean, all PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/connections test/features/connections test/architecture
git add -A lib/features/connections test/features/connections test/architecture/provider_tick_build_smoke_test.dart lib/l10n/arb
git commit -m "feat(connections): timeline slider beside Play on the canvas and in the Filter tab"
git show --stat HEAD
```

(Check `git show --stat` lists the three deleted source files, their tests, and the 22 l10n files.)

---

### Task 7: Verify and after screenshots

- [ ] **Step 1:** `dart format --set-exit-if-changed .` then `flutter analyze` (expect clean).
- [ ] **Step 2:** `flutter test test/features/connections test/architecture test/shared` (expect PASS).
- [ ] **Step 3:** Launch the app with the `run` skill; on Connections confirm by hand: dragging either thumb moves the label at once and the map follows; Play sweeps the end smoothly to the last day and flips back to Play; the Filter tab's control shows the same thumbs; on a phone-width window the bar spans the canvas above the sheet; on a wide window it stops at 560 px.
- [ ] **Step 4:** Capture the after screenshots matching Task 0: `01-connections-canvas-after.png`, `02-connections-canvas-after-phone.png`, `03-connections-filter-tab-after.png`, and the dark variants, plus one mid-sweep shot (`04-connections-canvas-playing-after.png`).
