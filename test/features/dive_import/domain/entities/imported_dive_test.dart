import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

void main() {
  group('ImportedDive', () {
    test('creates instance with required fields', () {
      final dive = ImportedDive(
        sourceId: 'healthkit-uuid-123',
        source: ImportSource.appleWatch,
        startTime: DateTime(2026, 1, 15, 10, 0),
        endTime: DateTime(2026, 1, 15, 10, 45),
        maxDepth: 18.5,
        profile: [],
      );

      expect(dive.sourceId, 'healthkit-uuid-123');
      expect(dive.source, ImportSource.appleWatch);
      expect(dive.maxDepth, 18.5);
    });

    test('calculates duration correctly', () {
      final dive = ImportedDive(
        sourceId: 'test',
        source: ImportSource.appleWatch,
        startTime: DateTime(2026, 1, 15, 10, 0),
        endTime: DateTime(2026, 1, 15, 10, 45),
        maxDepth: 18.5,
        profile: [],
      );

      expect(dive.duration, const Duration(minutes: 45));
    });

    test('ImportedProfileSample creates with all fields', () {
      const sample = ImportedProfileSample(
        timeSeconds: 120,
        depth: 15.5,
        temperature: 22.0,
        heartRate: 72,
      );

      expect(sample.timeSeconds, 120);
      expect(sample.depth, 15.5);
      expect(sample.temperature, 22.0);
      expect(sample.heartRate, 72);
    });
  });
}
