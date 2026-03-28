import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';

void main() {
  const converter = ImportedDiveConverter();

  group('ImportedDiveConverter', () {
    group('convert', () {
      test('maps basic fields from ImportedDive to Dive', () {
        final importedDive = ImportedDive(
          sourceId: 'hk-uuid-123',
          source: ImportSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 45),
          maxDepth: 25.3,
          avgDepth: 14.2,
          minTemperature: 18.5,
          profile: const [],
        );

        final dive = converter.convert(
          importedDive,
          diverId: 'diver-1',
          diveNumber: 42,
        );

        expect(dive.id, isNotEmpty);
        expect(dive.diverId, equals('diver-1'));
        expect(dive.diveNumber, equals(42));
        expect(dive.dateTime, equals(DateTime(2024, 6, 15, 10, 0)));
        expect(dive.entryTime, equals(DateTime(2024, 6, 15, 10, 0)));
        expect(dive.exitTime, equals(DateTime(2024, 6, 15, 10, 45)));
        // Runtime is total time (entry to exit), duration (bottom time)
        // is null when no profile is available to calculate from
        expect(dive.runtime, equals(const Duration(minutes: 45)));
        expect(dive.bottomTime, isNull);
        expect(dive.maxDepth, equals(25.3));
        expect(dive.avgDepth, equals(14.2));
        expect(dive.waterTemp, equals(18.5));
        expect(dive.importSource, equals('appleWatch'));
        expect(dive.importId, equals('hk-uuid-123'));
      });

      test('calculates bottom time from profile when available', () {
        // Profile: descent 0-60s, bottom at ~20m from 60-1500s, ascent 1500-1800s
        final importedDive = ImportedDive(
          sourceId: 'hk-uuid-bt',
          source: ImportSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 20.0,
          profile: const [
            ImportedProfileSample(timeSeconds: 0, depth: 0.0),
            ImportedProfileSample(timeSeconds: 60, depth: 18.0),
            ImportedProfileSample(timeSeconds: 300, depth: 20.0),
            ImportedProfileSample(timeSeconds: 900, depth: 19.0),
            ImportedProfileSample(timeSeconds: 1500, depth: 17.5),
            ImportedProfileSample(timeSeconds: 1650, depth: 5.0),
            ImportedProfileSample(timeSeconds: 1800, depth: 0.0),
          ],
        );

        final dive = converter.convert(importedDive, diverId: 'diver-1');

        // Runtime = 30 min (endTime - startTime)
        expect(dive.runtime, equals(const Duration(minutes: 30)));
        // Bottom time should be calculated from profile (< runtime)
        expect(dive.bottomTime, isNotNull);
        expect(dive.bottomTime!.inSeconds, lessThan(1800));
        expect(dive.bottomTime!.inSeconds, greaterThan(0));
      });

      test('generates unique UUIDs for each conversion', () {
        final importedDive = ImportedDive(
          sourceId: 'hk-uuid-123',
          source: ImportSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 45),
          maxDepth: 25.3,
          profile: const [],
        );

        final dive1 = converter.convert(importedDive);
        final dive2 = converter.convert(importedDive);

        expect(dive1.id, isNot(equals(dive2.id)));
      });

      test('handles null optional fields', () {
        final importedDive = ImportedDive(
          sourceId: 'hk-uuid-456',
          source: ImportSource.garmin,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 12.0,
          profile: const [],
        );

        final dive = converter.convert(importedDive);

        expect(dive.avgDepth, isNull);
        expect(dive.waterTemp, isNull);
        expect(dive.diverId, isNull);
        expect(dive.diveNumber, isNull);
        expect(dive.importSource, equals('garmin'));
      });

      test('converts profile samples to DiveProfilePoints', () {
        final importedDive = ImportedDive(
          sourceId: 'hk-uuid-789',
          source: ImportSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 20.0,
          profile: const [
            ImportedProfileSample(
              timeSeconds: 0,
              depth: 0.0,
              temperature: 22.0,
              heartRate: 80,
            ),
            ImportedProfileSample(
              timeSeconds: 60,
              depth: 10.5,
              temperature: 20.0,
              heartRate: 90,
            ),
            ImportedProfileSample(
              timeSeconds: 120,
              depth: 20.0,
              temperature: 18.0,
            ),
          ],
        );

        final dive = converter.convert(importedDive);

        expect(dive.profile, hasLength(3));

        // First sample
        expect(dive.profile[0].timestamp, equals(0));
        expect(dive.profile[0].depth, equals(0.0));
        expect(dive.profile[0].temperature, equals(22.0));
        expect(dive.profile[0].heartRate, equals(80));
        expect(dive.profile[0].heartRateSource, equals('appleWatch'));

        // Second sample
        expect(dive.profile[1].timestamp, equals(60));
        expect(dive.profile[1].depth, equals(10.5));
        expect(dive.profile[1].heartRate, equals(90));
        expect(dive.profile[1].heartRateSource, equals('appleWatch'));

        // Third sample - no heart rate
        expect(dive.profile[2].timestamp, equals(120));
        expect(dive.profile[2].depth, equals(20.0));
        expect(dive.profile[2].heartRate, isNull);
        expect(dive.profile[2].heartRateSource, isNull);
      });

      test('sets heartRateSource only when heartRate is present', () {
        final importedDive = ImportedDive(
          sourceId: 'hk-uuid-hr',
          source: ImportSource.suunto,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 15.0,
          profile: const [
            ImportedProfileSample(timeSeconds: 0, depth: 5.0, heartRate: 75),
            ImportedProfileSample(timeSeconds: 30, depth: 10.0),
          ],
        );

        final dive = converter.convert(importedDive);

        expect(dive.profile[0].heartRateSource, equals('suunto'));
        expect(dive.profile[1].heartRateSource, isNull);
      });

      test('maps all ImportSource values correctly', () {
        for (final source in ImportSource.values) {
          final importedDive = ImportedDive(
            sourceId: 'test-${source.name}',
            source: source,
            startTime: DateTime(2024, 6, 15, 10, 0),
            endTime: DateTime(2024, 6, 15, 10, 30),
            maxDepth: 10.0,
            profile: const [],
          );

          final dive = converter.convert(importedDive);

          expect(dive.importSource, equals(source.name));
        }
      });

      test('produces immutable Dive with empty defaults', () {
        final importedDive = ImportedDive(
          sourceId: 'hk-defaults',
          source: ImportSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 10.0,
          profile: const [],
        );

        final dive = converter.convert(importedDive);

        expect(dive.tanks, isEmpty);
        expect(dive.equipment, isEmpty);
        expect(dive.notes, isEmpty);
        expect(dive.photoIds, isEmpty);
        expect(dive.sightings, isEmpty);
        expect(dive.profile, isEmpty);
        expect(dive.isFavorite, isFalse);
      });

      test(
        'converter preserves importSource and importId from ImportedDive',
        () {
          final importedDive = ImportedDive(
            sourceId: 'abc123',
            source: ImportSource.suunto,
            startTime: DateTime(2026, 3, 15, 10, 0),
            endTime: DateTime(2026, 3, 15, 11, 0),
            maxDepth: 28.3,
            profile: [],
            sourceFileName: 'Suunto_Export.uddf',
            sourceFileFormat: 'uddf',
          );
          final dive = const ImportedDiveConverter().convert(importedDive);
          expect(dive.importSource, 'suunto');
          expect(dive.importId, 'abc123');
        },
      );
    });
  });
}
