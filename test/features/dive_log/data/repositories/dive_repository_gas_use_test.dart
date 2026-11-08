import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #2930: a dive read without its samples (a list row, an export)
/// reports the SAC the detail page works out from the profile, through the
/// gas-use window the derived metrics sweep stores.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  // 30 minutes at 18 m, then 10 minutes logged at the surface.
  final profile = [
    for (var t = 0; t <= 40 * 60; t += 10)
      domain.DiveProfilePoint(
        timestamp: t,
        depth: t == 0
            ? 0
            : t < 30 * 60
            ? 18
            : 0.3,
      ),
  ];

  Future<void> createDive({DiveMode diveMode = DiveMode.oc}) =>
      repository.createDive(
        domain.Dive(
          id: 'd',
          diveMode: diveMode,
          dateTime: DateTime.utc(2026, 5, 1, 10),
          runtime: const Duration(minutes: 40),
          avgDepth: 13.5,
          tanks: const [
            domain.DiveTank(
              id: 't',
              volume: 12,
              startPressure: 200,
              endPressure: 110,
            ),
          ],
          profile: profile,
        ),
      );

  Future<void> sweep() => DerivedMetricsRepository(
    runner: (input) async => computeDerivedMetricsFromBlobs(input),
  ).ensureCurrent('d');

  test('a list read reports the same SAC as the detail read', () async {
    await createDive();
    await sweep();

    final detail = (await repository.getDiveById('d'))!;
    final listed = (await repository.getAllDives()).single;

    expect(listed.profile, isEmpty);
    expect(listed.storedGasUse, detail.gasUse);
    expect(listed.sac, closeTo(detail.sac!, 1e-9));
  });

  test('a gauge dive with pressures agrees too', () async {
    await createDive(diveMode: DiveMode.gauge);
    await sweep();

    final detail = (await repository.getDiveById('d'))!;
    final listed = (await repository.getAllDives()).single;
    expect(listed.storedGasUse, isNotNull);
    expect(listed.sac, closeTo(detail.sac!, 1e-9));
  });

  test('before the sweep a list read keeps the untrimmed SAC', () async {
    await createDive();

    final listed = (await repository.getAllDives()).single;
    expect(listed.storedGasUse, isNull);
    final ambient = listed.environment.pressureAtDepth(13.5);
    expect(listed.sac, closeTo(90 / 40 / ambient, 1e-9));
  });

  test('the trimmed SAC is higher than the untrimmed one', () async {
    await createDive();
    await sweep();

    final listed = (await repository.getAllDives()).single;
    final ambient = listed.environment.pressureAtDepth(13.5);
    expect(listed.sac, greaterThan(90 / 40 / ambient));
  });
}
