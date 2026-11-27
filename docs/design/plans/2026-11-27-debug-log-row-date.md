# Debug Log Row Date Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every row in the debug log viewer shows its entry's date, in the diver's date format, ahead of the existing `HH:mm:ss.SSS` time.

**Architecture:** `LogEntryTile` becomes a `ConsumerWidget`, reads `unitFormatterProvider`, and builds its stamp as `formatter.formatDate(ts)` plus a space plus the existing fixed millisecond time. Nothing else in the viewer changes.

**Tech Stack:** Flutter, Riverpod, `intl` `DateFormat` (through `UnitFormatter`).

**Spec:** `docs/design/specs/2026-11-27-debug-log-row-date-design.md`

## Global Constraints

- The time part stays fixed 24-hour `HH:mm:ss.SSS`, whatever the diver's time format.
- The date part comes from `UnitFormatter.formatDate` (the diver's `DateFormatPreference`).
- No change to the log file format or to Copy, Save and Share output.

## Review Focus

- A diver on a month-name format (`MMM d, yyyy`): the stamp reads `Mar 27, 2026 14:32:01.123`, not a raw pattern. Pinned in Task 1.
- Two entries either side of midnight: they show different dates. Pinned in Task 1.
- A diver on 12-hour time: the time stays 24-hour with milliseconds. Pinned in Task 1.
- Existing tile behaviour (icon, tag, message, colours) is unchanged under the new `ProviderScope`. Covered by the existing tests, re-pumped through the new helper.
- The viewer page still builds (it already sits under the app's `ProviderScope`; its own tests cover it).

---

### Task 1: Date in the log row stamp

**Files:**
- Modify: `lib/features/settings/presentation/widgets/log_entry_tile.dart`
- Test: `test/features/settings/presentation/widgets/log_entry_tile_test.dart`

**Interfaces:**
- Consumes: `unitFormatterProvider` (`lib/core/utils/unit_formatter.dart`), `UnitFormatter.formatDate(DateTime?) -> String`.
- Produces: `class LogEntryTile extends ConsumerWidget` with the same constructor `LogEntryTile({Key? key, required LogEntry entry})`.

- [ ] **Step 1: Write the failing tests**

Change the test helper to wrap the tile in
`ProviderScope(overrides: [unitFormatterProvider.overrideWithValue(UnitFormatter(settings))])`,
taking an optional `AppSettings settings = const AppSettings(dateFormat: DateFormatPreference.ddmmyyyy)`.
Replace the existing `renders timestamp in HH:MM:SS.mmm format` test and add:

```dart
testWidgets('shows the date in the diver format before the time', ...)
  // ts = DateTime(2026, 3, 27, 14, 32, 1, 123), dd/MM/yyyy
  expect(find.text('27/03/2026 14:32:01.123'), findsOneWidget);

testWidgets('uses a month-name date format when the diver picks one', ...)
  // AppSettings(dateFormat: DateFormatPreference.mmmDYYYY)
  expect(find.text('Mar 27, 2026 14:32:01.123'), findsOneWidget);

testWidgets('keeps the 24-hour millisecond time under a 12-hour setting', ...)
  // AppSettings(dateFormat: ddmmyyyy, timeFormat: TimeFormat.twelveHour), ts 14:32:01.123
  expect(find.text('27/03/2026 14:32:01.123'), findsOneWidget);

testWidgets('entries either side of midnight show different dates', ...)
  // pump a Column of two tiles: DateTime(2026, 11, 23, 23, 59, 59, 999) and DateTime(2026, 11, 24, 0, 0, 0, 1)
  expect(find.text('23/11/2026 23:59:59.999'), findsOneWidget);
  expect(find.text('24/11/2026 00:00:00.001'), findsOneWidget);
```

Use the real `TimeFormat` enum value name from `lib/core/constants/units.dart`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/settings/presentation/widgets/log_entry_tile_test.dart`
Expected: the four new tests FAIL (the stamp has no date).

- [ ] **Step 3: Implement**

In `log_entry_tile.dart`, make the widget a `ConsumerWidget`, read
`ref.watch(unitFormatterProvider)`, and render
`'${formatter.formatDate(entry.timestamp)} ${_formatTime(entry.timestamp)}'`,
where `_formatTime` is the existing `_formatTimestamp` renamed.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/settings/presentation/widgets/log_entry_tile_test.dart test/features/settings/presentation/pages/debug_log_viewer_page_test.dart`
Expected: all PASS. The page test pumps real tiles under its own
`ProviderScope`; if `unitFormatterProvider` cannot resolve settings there,
override it in that test's scope the same way as the tile test.

- [ ] **Step 5: Format, analyze, commit**

Run `dart format .` and `flutter analyze` (no issues), then:

```bash
git add lib/features/settings/presentation/widgets/log_entry_tile.dart test/features/settings/presentation/widgets/log_entry_tile_test.dart
git commit -m "feat(settings): show the date on each debug log row"
```
