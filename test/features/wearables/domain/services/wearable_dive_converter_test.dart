import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';
import 'package:submersion/features/wearables/domain/services/wearable_dive_converter.dart';

void main() {
  const converter = WearableDiveConverter();

  group('WearableDiveConverter', () {
    group('convert', () {
      test('maps basic fields from WearableDive to Dive', () {
        final wearableDive = WearableDive(
          sourceId: 'hk-uuid-123',
          source: WearableSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 45),
          maxDepth: 25.3,
          avgDepth: 14.2,
          minTemperature: 18.5,
          profile: const [],
        );

        final dive = converter.convert(
          wearableDive,
          diverId: 'diver-1',
          diveNumber: 42,
        );

        expect(dive.id, isNotEmpty);
        expect(dive.diverId, equals('diver-1'));
        expect(dive.diveNumber, equals(42));
        expect(dive.dateTime, equals(DateTime(2024, 6, 15, 10, 0)));
        expect(dive.entryTime, equals(DateTime(2024, 6, 15, 10, 0)));
        expect(dive.exitTime, equals(DateTime(2024, 6, 15, 10, 45)));
        expect(dive.duration, equals(const Duration(minutes: 45)));
        expect(dive.maxDepth, equals(25.3));
        expect(dive.avgDepth, equals(14.2));
        expect(dive.waterTemp, equals(18.5));
        expect(dive.wearableSource, equals('appleWatch'));
        expect(dive.wearableId, equals('hk-uuid-123'));
      });

      test('generates unique UUIDs for each conversion', () {
        final wearableDive = WearableDive(
          sourceId: 'hk-uuid-123',
          source: WearableSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 45),
          maxDepth: 25.3,
          profile: const [],
        );

        final dive1 = converter.convert(wearableDive);
        final dive2 = converter.convert(wearableDive);

        expect(dive1.id, isNot(equals(dive2.id)));
      });

      test('handles null optional fields', () {
        final wearableDive = WearableDive(
          sourceId: 'hk-uuid-456',
          source: WearableSource.garmin,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 12.0,
          profile: const [],
        );

        final dive = converter.convert(wearableDive);

        expect(dive.avgDepth, isNull);
        expect(dive.waterTemp, isNull);
        expect(dive.diverId, isNull);
        expect(dive.diveNumber, isNull);
        expect(dive.wearableSource, equals('garmin'));
      });

      test('converts profile samples to DiveProfilePoints', () {
        final wearableDive = WearableDive(
          sourceId: 'hk-uuid-789',
          source: WearableSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 20.0,
          profile: const [
            WearableProfileSample(
              timeSeconds: 0,
              depth: 0.0,
              temperature: 22.0,
              heartRate: 80,
            ),
            WearableProfileSample(
              timeSeconds: 60,
              depth: 10.5,
              temperature: 20.0,
              heartRate: 90,
            ),
            WearableProfileSample(
              timeSeconds: 120,
              depth: 20.0,
              temperature: 18.0,
            ),
          ],
        );

        final dive = converter.convert(wearableDive);

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
        final wearableDive = WearableDive(
          sourceId: 'hk-uuid-hr',
          source: WearableSource.suunto,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 15.0,
          profile: const [
            WearableProfileSample(timeSeconds: 0, depth: 5.0, heartRate: 75),
            WearableProfileSample(timeSeconds: 30, depth: 10.0),
          ],
        );

        final dive = converter.convert(wearableDive);

        expect(dive.profile[0].heartRateSource, equals('suunto'));
        expect(dive.profile[1].heartRateSource, isNull);
      });

      test('maps all WearableSource values correctly', () {
        for (final source in WearableSource.values) {
          final wearableDive = WearableDive(
            sourceId: 'test-${source.name}',
            source: source,
            startTime: DateTime(2024, 6, 15, 10, 0),
            endTime: DateTime(2024, 6, 15, 10, 30),
            maxDepth: 10.0,
            profile: const [],
          );

          final dive = converter.convert(wearableDive);

          expect(dive.wearableSource, equals(source.name));
        }
      });

      test('produces immutable Dive with empty defaults', () {
        final wearableDive = WearableDive(
          sourceId: 'hk-defaults',
          source: WearableSource.appleWatch,
          startTime: DateTime(2024, 6, 15, 10, 0),
          endTime: DateTime(2024, 6, 15, 10, 30),
          maxDepth: 10.0,
          profile: const [],
        );

        final dive = converter.convert(wearableDive);

        expect(dive.tanks, isEmpty);
        expect(dive.equipment, isEmpty);
        expect(dive.notes, isEmpty);
        expect(dive.photoIds, isEmpty);
        expect(dive.sightings, isEmpty);
        expect(dive.profile, isEmpty);
        expect(dive.isFavorite, isFalse);
      });
    });
  });
}
