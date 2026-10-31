import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  late Database db;

  setUp(() {
    db = sqlite3.openInMemory();
    registerAppSqlFunctions(db);
  });

  tearDown(() => db.close());

  Object? ambient(
    Object? depth,
    Object? altitude,
    Object? surface,
    Object? w,
  ) => db.select('SELECT $kDiveAmbientBarFunction(?, ?, ?, ?) AS bar', [
    depth,
    altitude,
    surface,
    w,
  ]).single['bar'];

  test('reads the dive the way DiveEnvironment.forConditions does', () {
    final environment = DiveEnvironment.forConditions(
      altitudeMeters: 3000,
      waterType: WaterType.fresh,
    );

    expect(
      ambient(35.0, 3000.0, null, 'fresh'),
      closeTo(environment.pressureAtDepth(35), 1e-12),
    );
  });

  test('an explicit surface pressure wins over the altitude', () {
    final environment = DiveEnvironment.forConditions(
      altitudeMeters: 3000,
      surfacePressureBar: 0.95,
      waterType: WaterType.salt,
    );

    expect(
      ambient(20.0, 3000.0, 0.95, 'salt'),
      closeTo(environment.pressureAtDepth(20), 1e-12),
    );
  });

  test('a dive with no conditions keeps the standard environment', () {
    expect(ambient(10.0, null, null, null), closeTo(2.0, 1e-9));
  });

  test('no depth has no ambient pressure', () {
    expect(ambient(null, 3000.0, null, 'fresh'), isNull);
  });

  test('a surface pressure or altitude with no pressure is not used', () {
    // Past the top of the barometric formula, and a logged zero: a NULL here
    // would throw from the repositories reading this as a double.
    expect(ambient(10.0, 50000.0, null, null), closeTo(2.0, 1e-9));
    expect(ambient(10.0, null, 0.0, null), closeTo(2.0, 1e-9));
    expect(
      ambient(10.0, 3000.0, 0.0, null),
      closeTo(
        DiveEnvironment.forConditions(altitudeMeters: 3000).pressureAtDepth(10),
        1e-12,
      ),
    );
  });

  test('values a column should not hold fall back rather than throw', () {
    // A throw here would fail the whole statement, not this one row.
    expect(ambient(10.0, 'high', 'low', 'lake'), closeTo(2.0, 1e-9));
    expect(ambient('deep', null, null, null), isNull);
  });
}
