import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

void main() {
  test('ImportedDive carries enriched tank/deco/summary fields', () {
    final dive = ImportedDive(
      sourceId: 'garmin-1-2',
      sourceUuid: 'garmin-1-2',
      source: ImportSource.garmin,
      startTime: DateTime.utc(2025, 10, 13, 10, 51, 10),
      endTime: DateTime.utc(2025, 10, 13, 12, 18, 0),
      maxDepth: 34.2,
      diveNumber: 92,
      bottomTimeSeconds: 5169,
      surfaceIntervalSeconds: 167491,
      cnsEnd: 32,
      otu: 90,
      waterType: 'salt',
      decoModel: 'zhl_16c',
      gfLow: 50,
      gfHigh: 85,
      computerModel: 'Descent Mk3i',
      tanks: const [
        ImportedTank(
          order: 0,
          startPressureBar: 221.25,
          endPressureBar: 88.11,
          o2Percent: 30,
          hePercent: 0,
        ),
      ],
      profile: const [
        ImportedProfileSample(
          timeSeconds: 0,
          depth: 1.6,
          ceiling: 0,
          ndlSeconds: 0,
          tankPressures: [
            ImportedTankPressureSample(tankIndex: 0, pressureBar: 221.25),
          ],
        ),
      ],
    );

    expect(dive.diveNumber, 92);
    expect(dive.bottomTimeSeconds, 5169);
    expect(dive.tanks.single.startPressureBar, 221.25);
    expect(dive.profile.single.tankPressures!.single.pressureBar, 221.25);
  });

  test('value equality (props) holds across the import entities', () {
    const tank = ImportedTank(
      order: 0,
      startPressureBar: 200,
      endPressureBar: 80,
      volumeUsedLiters: 1000,
      o2Percent: 32,
      hePercent: 0,
    );
    expect(
      tank,
      equals(
        const ImportedTank(
          order: 0,
          startPressureBar: 200,
          endPressureBar: 80,
          volumeUsedLiters: 1000,
          o2Percent: 32,
          hePercent: 0,
        ),
      ),
    );
    expect(tank, isNot(equals(const ImportedTank(order: 1))));

    const pressure = ImportedTankPressureSample(tankIndex: 0, pressureBar: 200);
    expect(
      pressure,
      equals(const ImportedTankPressureSample(tankIndex: 0, pressureBar: 200)),
    );
    expect(
      pressure,
      isNot(
        equals(const ImportedTankPressureSample(tankIndex: 1, pressureBar: 9)),
      ),
    );

    const sample = ImportedProfileSample(
      timeSeconds: 5,
      depth: 10,
      temperature: 22,
      heartRate: 70,
      cns: 1,
      ndlSeconds: 99,
      ttsSeconds: 0,
      ceiling: 0,
    );
    expect(sample, equals(sample));
    expect(
      sample,
      isNot(equals(const ImportedProfileSample(timeSeconds: 6, depth: 10))),
    );

    ImportedDive makeDive() => ImportedDive(
      sourceId: 'a',
      source: ImportSource.garmin,
      startTime: DateTime.utc(2025),
      endTime: DateTime.utc(2025, 1, 1, 1),
      maxDepth: 10,
      profile: const [],
    );
    expect(makeDive(), equals(makeDive()));
  });

  test('ImportedProfileSample.copyWith adds tank pressures', () {
    const s = ImportedProfileSample(timeSeconds: 5, depth: 10.0);
    final merged = s.copyWith(
      tankPressures: const [
        ImportedTankPressureSample(tankIndex: 0, pressureBar: 200.0),
      ],
    );
    expect(merged.depth, 10.0);
    expect(merged.timeSeconds, 5);
    expect(merged.tankPressures!.single.pressureBar, 200.0);
  });
}
