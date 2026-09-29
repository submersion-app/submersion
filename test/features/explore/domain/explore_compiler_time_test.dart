import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Relative periods are calendar arithmetic, never elapsed time: a Duration
/// from a local midnight lands a day early across a spring-forward change,
/// and DateTime rolls "February 31" into March.
void main() {
  const units = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );

  ExploreCompilation compileTime(String text, DateTime now) =>
      ExploreCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'time': {'text': text},
        }),
        ExploreCompilerContext(units: units, names: NameIndex.empty, now: now),
      );

  test('last 1 month on the 31st starts on the last day of February', () {
    // Counted months keep the day of month, clamped: DateTime(2026, 2, 31)
    // would roll to 3 March and drop most of February.
    final q = compileTime('last 1 month', DateTime(2026, 3, 31));
    expect(q.filter.startDate, DateTime(2026, 2, 28));
    expect(q.filter.endDate, DateTime(2026, 3, 31));
  });

  test('last month is the previous calendar month, not a counted span', () {
    final q = compileTime('last month', DateTime(2026, 3, 31));
    expect(q.filter.startDate, DateTime(2026, 2, 1));
    expect(q.filter.endDate, DateTime(2026, 2, 28));
  });

  test('last N days counts calendar days, not 24-hour spans', () {
    final q = compileTime('last 30 days', DateTime(2026, 4, 10));
    // Thirty calendar days before 10 April is 11 March, whatever DST did in
    // between. A Duration would give 10 March at 23:00 in a zone that sprang
    // forward, which the date axis reads as the day before.
    final start = q.filter.startDate!;
    expect(DateTime(start.year, start.month, start.day), DateTime(2026, 3, 11));
    expect(start.hour, 0);
  });

  test('last year on 29 February starts on 28 February', () {
    final q = compileTime('last 1 year', DateTime(2028, 2, 29));
    expect(q.filter.startDate, DateTime(2027, 2, 28));
  });
}
