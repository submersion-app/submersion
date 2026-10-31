import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/demo_mode/data/demo_date_columns.dart';

int calendarDaysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
  });

  tearDown(() => db.close());

  Set<String> schemaColumns() => {
    for (final t in db.allTables)
      for (final c in t.$columns) '${t.actualTableName}.${c.name}',
  };

  test(
    'every column whose name could be a duration or an instant is classified',
    () {
      final ambiguous = RegExp(r'(time|_since|_until|_on)$');
      final unclassified = <String>[];
      for (final t in db.allTables) {
        for (final c in t.$columns) {
          final key = '${t.actualTableName}.${c.name}';
          if (c.type != DriftSqlType.int || !ambiguous.hasMatch(c.name)) {
            continue;
          }
          if (!demoShiftedTimeColumns.contains(key) &&
              !demoNotDateColumns.containsKey(key)) {
            unclassified.add(key);
          }
        }
      }

      expect(
        unclassified,
        isEmpty,
        reason:
            'Add each to demoShiftedTimeColumns (an instant) or '
            'demoNotDateColumns (with the reason it is not one)',
      );
    },
  );

  test('every listed column exists in the schema', () {
    final columns = schemaColumns();

    expect(
      [
        ...demoShiftedTimeColumns,
        ...demoNotDateColumns.keys,
      ].where((c) => !columns.contains(c)),
      isEmpty,
    );
  });

  test('the shift set holds instants and never durations', () {
    final shifted = {
      for (final c in demoDateColumnsOf(db)) '${c.table}.${c.column}',
    };

    expect(shifted, containsAll(['dives.dive_date_time', 'dives.entry_time']));
    expect(
      shifted,
      containsAll(['trips.start_date', 'certifications.expiry_date']),
    );
    expect(shifted, contains('dive_data_sources.imported_at'));
    expect(shifted, isNot(contains('dives.bottom_time')));
    expect(shifted, isNot(contains('dives.runtime')));
    expect(shifted, isNot(contains('divers.diving_since')));
    // Minutes after local midnight, despite the `_at` in their names.
    expect(shifted, isNot(contains('dive_centers.fill_opens_at')));
    expect(shifted, isNot(contains('dive_centers.fill_closes_at')));
  });

  test('DateTime columns shift in seconds and int columns in milliseconds', () {
    final byKey = {
      for (final c in demoDateColumnsOf(db)) '${c.table}.${c.column}': c.unit,
    };

    expect(byKey['dive_data_sources.entry_time'], DemoDateUnit.epochSeconds);
    expect(byKey['dives.dive_date_time'], DemoDateUnit.epochMillis);
  });

  test(
    'demoShiftFor lands the latest dive 7 to 13 days ago and keeps the weekday',
    () {
      final now = DateTime(2026, 10, 26, 12);
      for (final latest in [
        DateTime(2024, 1, 3, 9),
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 25, 23),
        DateTime(2027, 3, 1, 9),
      ]) {
        final shifted = latest.add(demoShiftFor(latestDive: latest, now: now));
        expect(
          calendarDaysBetween(shifted, now),
          inInclusiveRange(7, 13),
          reason: '$latest',
        );
        expect(shifted.weekday, latest.weekday, reason: '$latest');
      }
    },
  );

  test('demoShiftFor keeps the seasons when whole years land the latest dive '
      'within six weeks', () {
    final now = DateTime(2026, 10, 26, 12);
    for (final (latest, years) in [
      // A year and 26 days old: back a year to late September.
      (DateTime(2025, 10, 1, 9), 1),
      // Opened 25 days after its build: dates stay as built.
      (DateTime(2026, 10, 1, 9), 0),
      // Three years and five weeks old.
      (DateTime(2023, 9, 25, 9), 3),
    ]) {
      final shift = demoShiftFor(latestDive: latest, now: now);
      final shifted = latest.add(shift);
      // Whole 52-week years keep every weekday and drift a season by only a
      // day or so a year.
      expect(shift, Duration(days: 364 * years), reason: '$latest');
      expect(
        calendarDaysBetween(shifted, now),
        inInclusiveRange(7, 42),
        reason: '$latest',
      );
      expect(shifted.weekday, latest.weekday, reason: '$latest');
    }
  });

  test('demoShiftFor shifts by weeks once whole years would leave the latest '
      'dive over six weeks back', () {
    final now = DateTime(2026, 10, 26, 12);
    final latest = DateTime(2026, 9, 13, 9); // 43 days back.
    final shifted = latest.add(demoShiftFor(latestDive: latest, now: now));

    expect(calendarDaysBetween(shifted, now), inInclusiveRange(7, 13));
  });
}
