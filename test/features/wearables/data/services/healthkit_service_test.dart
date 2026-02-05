import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/wearables/data/services/healthkit_service.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

@GenerateMocks([Health])
import 'healthkit_service_test.mocks.dart';

void main() {
  group('HealthKitService', () {
    late MockHealth mockHealth;
    late HealthKitService service;

    setUp(() {
      mockHealth = MockHealth();
      service = HealthKitService(health: mockHealth);
    });

    group('source', () {
      test('returns WearableSource.appleWatch', () {
        expect(service.source, equals(WearableSource.appleWatch));
      });
    });

    group('isAvailable', () {
      test('returns false when hasPermissions throws', () async {
        when(mockHealth.hasPermissions(any)).thenThrow(Exception('Not available'));

        final result = await service.isAvailable();

        expect(result, isFalse);
      });

      test('returns false when hasPermissions returns null', () async {
        when(mockHealth.hasPermissions(any)).thenAnswer((_) async => null);

        final result = await service.isAvailable();

        expect(result, isFalse);
      });

      test('returns true when hasPermissions returns true', () async {
        when(mockHealth.hasPermissions(any)).thenAnswer((_) async => true);

        final result = await service.isAvailable();

        expect(result, isTrue);
      });
    });

    group('hasPermissions', () {
      test('returns false when hasPermissions throws', () async {
        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenThrow(Exception('Error'));

        final result = await service.hasPermissions();

        expect(result, isFalse);
      });

      test('returns false when hasPermissions returns null', () async {
        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => null);

        final result = await service.hasPermissions();

        expect(result, isFalse);
      });

      test('returns true when hasPermissions returns true', () async {
        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);

        final result = await service.hasPermissions();

        expect(result, isTrue);
      });
    });

    group('requestPermissions', () {
      test('configures health and requests authorization', () async {
        when(mockHealth.configure()).thenAnswer((_) async {});
        when(mockHealth.requestAuthorization(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);

        final result = await service.requestPermissions();

        expect(result, isTrue);
        verify(mockHealth.configure()).called(1);
        verify(mockHealth.requestAuthorization(any, permissions: anyNamed('permissions')))
            .called(1);
      });

      test('returns false when configure throws', () async {
        when(mockHealth.configure()).thenThrow(Exception('Error'));

        final result = await service.requestPermissions();

        expect(result, isFalse);
      });

      test('returns false when requestAuthorization returns false', () async {
        when(mockHealth.configure()).thenAnswer((_) async {});
        when(mockHealth.requestAuthorization(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => false);

        final result = await service.requestPermissions();

        expect(result, isFalse);
      });
    });

    group('fetchDives', () {
      test('returns empty list when no permissions', () async {
        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => false);

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('returns empty list when getHealthDataFromTypes throws', () async {
        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);
        when(mockHealth.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenThrow(Exception('Error'));

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('returns empty list when no diving workouts found', () async {
        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);
        when(mockHealth.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenAnswer((_) async => []);

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('filters out non-diving workouts', () async {
        final runningWorkout = _createMockWorkoutDataPoint(
          uuid: 'running-uuid',
          startTime: DateTime(2024, 1, 15, 10, 0),
          endTime: DateTime(2024, 1, 15, 11, 0),
          activityType: HealthWorkoutActivityType.RUNNING,
        );

        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);
        when(mockHealth.getHealthDataFromTypes(
          types: anyNamed('types'),
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenAnswer((_) async => [runningWorkout]);

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('converts diving workouts to WearableDive entities', () async {
        final divingWorkout = _createMockWorkoutDataPoint(
          uuid: 'dive-uuid-123',
          startTime: DateTime(2024, 1, 15, 9, 0),
          endTime: DateTime(2024, 1, 15, 10, 0),
          activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
        );

        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);

        // First call for workouts
        when(mockHealth.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenAnswer((_) async => [divingWorkout]);

        // Second call for heart rate samples
        when(mockHealth.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenAnswer((_) async => []);

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, hasLength(1));
        expect(result.first.sourceId, equals('dive-uuid-123'));
        expect(result.first.source, equals(WearableSource.appleWatch));
        expect(result.first.startTime, equals(DateTime(2024, 1, 15, 9, 0)));
        expect(result.first.endTime, equals(DateTime(2024, 1, 15, 10, 0)));
      });

      test('sorts dives by start time descending', () async {
        final olderDive = _createMockWorkoutDataPoint(
          uuid: 'older-dive',
          startTime: DateTime(2024, 1, 10, 9, 0),
          endTime: DateTime(2024, 1, 10, 10, 0),
          activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
        );

        final newerDive = _createMockWorkoutDataPoint(
          uuid: 'newer-dive',
          startTime: DateTime(2024, 1, 20, 9, 0),
          endTime: DateTime(2024, 1, 20, 10, 0),
          activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
        );

        when(mockHealth.hasPermissions(any, permissions: anyNamed('permissions')))
            .thenAnswer((_) async => true);

        // Return older dive first
        when(mockHealth.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenAnswer((_) async => [olderDive, newerDive]);

        when(mockHealth.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: anyNamed('startTime'),
          endTime: anyNamed('endTime'),
        )).thenAnswer((_) async => []);

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, hasLength(2));
        // Newer dive should be first
        expect(result[0].sourceId, equals('newer-dive'));
        expect(result[1].sourceId, equals('older-dive'));
      });
    });

    group('fetchDiveProfile', () {
      test('returns empty list (profile fetched with dive)', () async {
        final result = await service.fetchDiveProfile('any-id');
        expect(result, isEmpty);
      });
    });
  });
}

/// Helper to create a mock workout data point for testing.
HealthDataPoint _createMockWorkoutDataPoint({
  required String uuid,
  required DateTime startTime,
  required DateTime endTime,
  required HealthWorkoutActivityType activityType,
}) {
  return HealthDataPoint(
    uuid: uuid,
    value: WorkoutHealthValue(
      workoutActivityType: activityType,
      totalEnergyBurned: 0,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      totalDistance: 0,
      totalDistanceUnit: HealthDataUnit.METER,
    ),
    type: HealthDataType.WORKOUT,
    unit: HealthDataUnit.NO_UNIT,
    dateFrom: startTime,
    dateTo: endTime,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'apple-watch',
    sourceId: 'com.apple.health',
    sourceName: 'Apple Watch',
  );
}
