import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #810: raw O2 cell output has to survive the write/read round trip,
/// including the case that motivated it -- millivolts present with no per-cell
/// ppO2 beside them, because the logged calibration was a factory default.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<List<domain.DiveProfilePoint>> writeAndRead(
    String id,
    List<domain.DiveProfilePoint> profile,
  ) async {
    await repository.createDive(
      domain.Dive(
        id: id,
        dateTime: DateTime.utc(2026, 8, 15, 10),
        profile: profile,
      ),
    );
    return repository.getMergedProfile(id);
  }

  test('millivolts survive the write/read round trip', () async {
    final merged = await writeAndRead('mv1', [
      const domain.DiveProfilePoint(
        timestamp: 0,
        depth: 5.0,
        o2SensorMv1: 58,
        o2SensorMv2: 61,
        o2SensorMv3: 43,
      ),
      const domain.DiveProfilePoint(
        timestamp: 10,
        depth: 10.0,
        o2SensorMv1: 59,
        o2SensorMv2: 60,
        o2SensorMv3: 41,
      ),
    ]);

    expect(merged, hasLength(2));
    expect(merged[0].o2SensorMv1, 58);
    expect(merged[0].o2SensorMv2, 61);
    expect(merged[0].o2SensorMv3, 43);
    expect(merged[1].o2SensorMv1, 59);
    expect(merged[1].o2SensorMv3, 41);
  });

  test('unreported cells read back as null, not zero', () async {
    final merged = await writeAndRead('mv2', [
      const domain.DiveProfilePoint(timestamp: 0, depth: 5.0, o2SensorMv1: 58),
    ]);

    expect(merged.single.o2SensorMv1, 58);
    expect(merged.single.o2SensorMv4, isNull);
    expect(merged.single.o2SensorMv5, isNull);
    expect(merged.single.o2SensorMv6, isNull);
  });

  test('millivolts persist without any per-cell ppO2 present', () async {
    final merged = await writeAndRead('mv3', [
      const domain.DiveProfilePoint(
        timestamp: 0,
        depth: 5.0,
        ppO2: 1.19,
        o2SensorMv1: 58,
        o2SensorMv2: 61,
        o2SensorMv3: 43,
      ),
    ]);

    expect(merged.single.o2SensorMv1, 58);
    expect(merged.single.o2Sensor1, isNull);
    // The aggregate is unaffected by any of this.
    expect(merged.single.ppO2, 1.19);
  });

  test('both readings coexist when the calibration is trustworthy', () async {
    final merged = await writeAndRead('mv4', [
      const domain.DiveProfilePoint(
        timestamp: 0,
        depth: 5.0,
        o2Sensor1: 0.98,
        o2SensorMv1: 49,
      ),
    ]);

    expect(merged.single.o2Sensor1, 0.98);
    expect(merged.single.o2SensorMv1, 49);
  });
}
