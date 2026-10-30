import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/shape/shape_extractor.dart';

/// A 45 m dive with a 50% deco gas: depth, temperature and a pressure trace
/// on each tank.
domain.Dive decoDive({DiveMode mode = DiveMode.oc, double backHe = 0}) =>
    domain.Dive(
      id: 'dive-1',
      dateTime: DateTime(2023, 4, 5, 9, 30),
      diveMode: mode,
      maxDepth: 45,
      runtime: const Duration(minutes: 60),
      notes: 'Secret reef note about Blue Hole',
      buddy: 'Jane Diver',
      diveComputerSerial: 'SN-998877',
      tanks: [
        domain.DiveTank(
          id: 't-back',
          volume: 24,
          startPressure: 220,
          endPressure: 90,
          gasMix: domain.GasMix(o2: 21, he: backHe),
          role: TankRole.backGas,
        ),
        const domain.DiveTank(
          id: 't-deco',
          volume: 11,
          startPressure: 200,
          endPressure: 150,
          gasMix: domain.GasMix(o2: 50),
          role: TankRole.deco,
          order: 1,
        ),
      ],
      profile: [
        for (var t = 0; t <= 3600; t += 10)
          domain.DiveProfilePoint(
            timestamp: t,
            depth: t < 300
                ? t / 300 * 45
                : (t < 1800 ? 45 : 45 - (t - 1800) / 40),
            temperature: 18 - t / 3600,
            ppO2: mode == DiveMode.ccr ? 1.3 : null,
            o2Sensor1: mode == DiveMode.ccr ? 1.29 : null,
            o2Sensor2: mode == DiveMode.ccr ? 1.31 : null,
            o2Sensor3: mode == DiveMode.ccr ? 1.3 : null,
            setpoint: mode == DiveMode.ccr ? 1.3 : null,
          ),
      ],
    );

final pressures = {
  't-back': [
    for (var t = 0; t <= 3600; t += 60)
      domain.TankPressurePoint(
        tankId: 't-back',
        timestamp: t,
        pressure: 220 - t / 3600 * 130,
      ),
  ],
};

void main() {
  test('fromDive keeps depth, temperature, gases and per-tank pressure', () {
    final shape = ShapeExtractor().fromDive(decoDive(), pressures);

    expect(shape.samples.length, 361);
    expect(shape.samples[100].depth, closeTo(45, 0.01));
    expect(shape.samples.first.temp, 18);
    expect(shape.tanks.map((t) => t.o2), [21, 50]);
    expect(shape.tanks.first.pressures.length, 61);
    expect(shape.tanks.first.volumeL, 24);
    expect(shape.sampleIntervalSec, 10);
    expect(shape.diveMode, 'oc');
  });

  test('a CCR dive keeps its cell readings and setpoints', () {
    final shape = ShapeExtractor().fromDive(
      decoDive(mode: DiveMode.ccr),
      const {},
    );

    expect(shape.samples[50].cells, [1.29, 1.31, 1.3]);
    expect(shape.samples[50].setpoint, 1.3);
    expect(shape.kinds, contains(ShapeKind.ccr));
  });

  test(
    "the shape's JSON carries none of the dive's dates, names, notes or serials",
    () {
      final json = jsonEncode(
        ShapeExtractor().fromDive(decoDive(), pressures).toJson(),
      );

      for (final secret in [
        'Secret',
        'Blue Hole',
        'Jane',
        'SN-998877',
        '2023',
        'dive-1',
        't-back',
      ]) {
        expect(json, isNot(contains(secret)), reason: secret);
      }
    },
  );

  test('kinds classify deep, multi-gas and trimix dives', () {
    final oc = ShapeExtractor().fromDive(decoDive(), pressures);
    expect(
      oc.kinds,
      containsAll([
        ShapeKind.deepOpenCircuit,
        ShapeKind.multiGasDeco,
        ShapeKind.tankPressure,
      ]),
    );
    expect(oc.kinds, isNot(contains(ShapeKind.trimix)));

    final tx = ShapeExtractor().fromDive(decoDive(backHe: 35), pressures);
    expect(tx.kinds, contains(ShapeKind.trimix));
  });

  test('the same curve gives the same id, a different one another', () {
    final a = ShapeExtractor().fromDive(decoDive(), pressures);
    final b = ShapeExtractor().fromDive(decoDive(), const {});
    final c = ShapeExtractor().fromDive(
      decoDive().copyWith(
        profile: [
          for (final p in decoDive().profile) p.copyWith(depth: p.depth / 2),
        ],
      ),
      const {},
    );

    expect(a.id, b.id);
    expect(a.id, isNot(c.id));
  });

  test('a shape round-trips through JSON', () {
    final shape = ShapeExtractor().fromDive(
      decoDive(mode: DiveMode.ccr),
      pressures,
    );

    expect(
      jsonEncode(DiveShape.fromJson(shape.toJson()).toJson()),
      jsonEncode(shape.toJson()),
    );
  });

  group('fromDatabase', () {
    setUp(() async => setUpTestDatabase());
    tearDown(() async => tearDownTestDatabase());

    test('reads every dive with its profile and tank pressures', () async {
      await DiveRepository().createDive(decoDive());
      await TankPressureRepository().insertTankPressures('dive-1', {
        't-back': [
          for (final p in pressures['t-back']!)
            (timestamp: p.timestamp, pressure: p.pressure),
        ],
      });

      final shapes = await ShapeExtractor().fromDatabase();

      expect(shapes, hasLength(1));
      expect(shapes.single.samples.length, 361);
      expect(shapes.single.tanks.first.pressures, hasLength(61));
    });

    test('skips dives without a profile', () async {
      await DiveRepository().createDive(
        domain.Dive(id: 'flat', dateTime: DateTime(2023)),
      );

      expect(await ShapeExtractor().fromDatabase(), isEmpty);
    });
  });
}
