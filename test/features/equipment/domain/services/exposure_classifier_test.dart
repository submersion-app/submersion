import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';

void main() {
  final d = DateTime(2026, 6, 1);
  EquipmentExposureSample sample({
    int seconds = 3600,
    DiveMode mode = DiveMode.oc,
    double? depth,
    double? temp,
    WaterType? water,
    double? o2,
  }) => EquipmentExposureSample(
    date: d,
    durationSeconds: seconds,
    diveMode: mode,
    maxDepth: depth,
    minTemperature: temp,
    waterType: water,
    contactO2Fraction: o2,
  );
  const c = ExposureClassifier();

  test('dives and cycles count one per sample; hours are duration', () {
    final s = sample(seconds: 5400);
    expect(c.contribution(s, ExposureUnit.dives), 1);
    expect(c.contribution(s, ExposureUnit.cycles), 1);
    expect(c.contribution(s, ExposureUnit.hours), closeTo(1.5, 1e-9));
    expect(c.contribution(s, ExposureUnit.days), 0);
  });

  test('salt hours count salt and brackish, not fresh or unknown', () {
    expect(
      c.contribution(sample(water: WaterType.salt), ExposureUnit.saltHours),
      1,
    );
    expect(
      c.contribution(sample(water: WaterType.brackish), ExposureUnit.saltHours),
      1,
    );
    expect(
      c.contribution(sample(water: WaterType.fresh), ExposureUnit.saltHours),
      0,
    );
    expect(c.contribution(sample(), ExposureUnit.saltHours), 0);
  });

  test('cold is strictly below the line; unknown temperature is not cold', () {
    expect(c.contribution(sample(temp: 9.9), ExposureUnit.coldDives), 1);
    expect(c.contribution(sample(temp: 10.0), ExposureUnit.coldDives), 0);
    expect(c.contribution(sample(), ExposureUnit.coldDives), 0);
  });

  test('deep is at or beyond the line', () {
    expect(c.contribution(sample(depth: 30.0), ExposureUnit.deepCycles), 1);
    expect(c.contribution(sample(depth: 29.9), ExposureUnit.deepCycles), 0);
    expect(c.contribution(sample(), ExposureUnit.deepCycles), 0);
  });

  test('O2 hours need contact strictly above the line', () {
    expect(c.contribution(sample(o2: 0.40), ExposureUnit.o2Hours), 0);
    expect(c.contribution(sample(o2: 0.41), ExposureUnit.o2Hours), 1);
    expect(c.contribution(sample(), ExposureUnit.o2Hours), 0);
  });

  test('custom thresholds move every line', () {
    const cold = ExposureClassifier(
      thresholds: ExposureThresholds(
        coldWaterC: 15,
        deepDiveM: 20,
        highO2Fraction: 0.30,
      ),
    );
    expect(cold.contribution(sample(temp: 14), ExposureUnit.coldDives), 1);
    expect(cold.contribution(sample(depth: 20), ExposureUnit.deepCycles), 1);
    expect(cold.contribution(sample(o2: 0.32), ExposureUnit.o2Hours), 1);
  });

  test('a rebreather counts loop hours only, but salt hours regardless', () {
    const loop = ExposureClassifier(loopTimeOnly: true);
    expect(loop.contribution(sample(mode: DiveMode.oc), ExposureUnit.hours), 0);
    expect(
      loop.contribution(sample(mode: DiveMode.gauge), ExposureUnit.hours),
      0,
    );
    expect(
      loop.contribution(sample(mode: DiveMode.ccr), ExposureUnit.hours),
      1,
    );
    expect(
      loop.contribution(sample(mode: DiveMode.scr), ExposureUnit.hours),
      1,
    );
    expect(
      loop.contribution(
        sample(mode: DiveMode.oc, water: WaterType.salt),
        ExposureUnit.saltHours,
      ),
      1,
    );
  });

  test('a parent with a battery child accrues no cycles', () {
    const parent = ExposureClassifier(hasBatteryChild: true);
    expect(parent.contribution(sample(), ExposureUnit.cycles), 0);
    expect(parent.contribution(sample(), ExposureUnit.dives), 1);
  });

  test('totals sum every unit over the samples', () {
    final totals = c.totals([
      sample(seconds: 3600, water: WaterType.salt, temp: 5, depth: 35, o2: 0.5),
      sample(seconds: 1800, water: WaterType.fresh, temp: 20, depth: 10),
    ]);
    expect(totals[ExposureUnit.dives], 2);
    expect(totals[ExposureUnit.hours], closeTo(1.5, 1e-9));
    expect(totals[ExposureUnit.saltHours], closeTo(1.0, 1e-9));
    expect(totals[ExposureUnit.coldDives], 1);
    expect(totals[ExposureUnit.deepCycles], 1);
    expect(totals[ExposureUnit.o2Hours], closeTo(1.0, 1e-9));
    expect(totals[ExposureUnit.cycles], 2);
    expect(totals[ExposureUnit.days], 0);
  });
}
