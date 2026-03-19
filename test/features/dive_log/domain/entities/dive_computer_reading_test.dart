import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer_reading.dart';

void main() {
  group('DiveComputerReading', () {
    test('constructs with required fields', () {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      expect(reading.id, 'r1');
      expect(reading.diveId, 'd1');
      expect(reading.isPrimary, true);
      expect(reading.maxDepth, isNull);
      expect(reading.computerModel, isNull);
    });

    test('constructs with all fields', () {
      final now = DateTime.now();
      final entry = DateTime(2026, 3, 19, 10, 0);
      final exit = DateTime(2026, 3, 19, 10, 42);
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        computerId: 'c1',
        isPrimary: true,
        computerModel: 'Shearwater Perdix',
        computerSerial: 'SN12345',
        sourceFormat: 'UDDF',
        maxDepth: 30.2,
        avgDepth: 18.4,
        duration: 2535,
        waterTemp: 26.1,
        entryTime: entry,
        exitTime: exit,
        maxAscentRate: 9.5,
        maxDescentRate: 18.0,
        surfaceInterval: 65,
        cns: 12.0,
        otu: 22.0,
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gradientFactorLow: 30,
        gradientFactorHigh: 70,
        importedAt: now,
        createdAt: now,
      );

      expect(reading.computerModel, 'Shearwater Perdix');
      expect(reading.maxDepth, 30.2);
      expect(reading.duration, 2535);
      expect(reading.gradientFactorLow, 30);
    });

    test('copyWith replaces specified fields', () {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        maxDepth: 30.2,
        computerModel: 'Shearwater Perdix',
        importedAt: now,
        createdAt: now,
      );

      final updated = reading.copyWith(isPrimary: false, maxDepth: 29.8);

      expect(updated.isPrimary, false);
      expect(updated.maxDepth, 29.8);
      expect(updated.id, 'r1');
      expect(updated.computerModel, 'Shearwater Perdix');
    });

    test('copyWith preserves null fields when not specified', () {
      final now = DateTime.now();
      final reading = DiveComputerReading(
        id: 'r1',
        diveId: 'd1',
        isPrimary: true,
        importedAt: now,
        createdAt: now,
      );

      final updated = reading.copyWith(isPrimary: false);

      expect(updated.maxDepth, isNull);
      expect(updated.computerModel, isNull);
    });
  });
}
