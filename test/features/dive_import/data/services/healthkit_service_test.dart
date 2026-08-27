import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/data/services/healthkit_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';

@GenerateMocks([Health])
import 'healthkit_service_test.mocks.dart';

void main() {
  group('HealthKitService', () {
    late MockHealth mockHealth;
    late HealthKitService service;

    setUp(() {
      mockHealth = MockHealth();
      service = HealthKitService(health: mockHealth, isPlatformSupported: true);
    });

    group('source', () {
      test('returns ImportSource.appleWatch', () {
        expect(service.source, equals(ImportSource.appleWatch));
      });
    });

    group('isAvailable', () {
      test('reports device capability, not permission state', () async {
        expect(await service.isAvailable(), isTrue);
        expect(
          await HealthKitService(
            health: mockHealth,
            isPlatformSupported: false,
          ).isAvailable(),
          isFalse,
        );
        verifyNever(mockHealth.hasPermissions(any));
      });

      test('is false when the device has no HealthKit', () async {
        // Platform.isIOS is not a capability check: iPadOS before 17 has no
        // Health app at all. HKHealthStore.isHealthDataAvailable() is.
        expect(
          await _serviceWithProbe(mockHealth, false).isAvailable(),
          isFalse,
        );
      });

      test('is true when the probe cannot answer', () async {
        // Unknown is not a refusal.
        expect(await _serviceWithProbe(mockHealth, null).isAvailable(), isTrue);
      });

      test('is true when the probe throws', () async {
        final thrower = HealthKitService(
          health: mockHealth,
          isPlatformSupported: true,
          healthDataAvailable: () async => throw Exception('no channel'),
        );

        expect(await thrower.isAvailable(), isTrue);
      });
    });

    group('device capability gating', () {
      test('permissionStatus is unsupported without HealthKit', () async {
        expect(
          await _serviceWithProbe(mockHealth, false).permissionStatus(),
          equals(HealthPermissionStatus.unsupported),
        );
        verifyNever(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        );
      });

      test('requestPermissions is refused without HealthKit', () async {
        expect(
          await _serviceWithProbe(mockHealth, false).requestPermissions(),
          isFalse,
        );
        verifyNever(mockHealth.configure());
      });

      test('fetchDives returns nothing without HealthKit', () async {
        expect(
          await _serviceWithProbe(mockHealth, false).fetchDives(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
          ),
          isEmpty,
        );
      });

      test('asks the platform once and reuses the answer', () async {
        // Whether the hardware has HealthKit cannot change while the app
        // runs, and every entry point needs the answer.
        var probes = 0;
        final counted = HealthKitService(
          health: mockHealth,
          isPlatformSupported: true,
          healthDataAvailable: () async {
            probes++;
            return true;
          },
        );
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => null);
        when(
          mockHealth.getHealthDataFromTypes(
            types: anyNamed('types'),
            startTime: anyNamed('startTime'),
            endTime: anyNamed('endTime'),
          ),
        ).thenAnswer((_) async => []);

        await counted.isAvailable();
        await counted.permissionStatus();
        await counted.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(probes, equals(1));
      });

      test('shares one probe across concurrent callers', () async {
        var probes = 0;
        final counted = HealthKitService(
          health: mockHealth,
          isPlatformSupported: true,
          healthDataAvailable: () async {
            probes++;
            await Future<void>.delayed(Duration.zero);
            return true;
          },
        );

        await Future.wait([
          counted.isAvailable(),
          counted.isAvailable(),
          counted.isAvailable(),
        ]);

        expect(probes, equals(1));
      });

      test('an unknown probe never blocks the read', () async {
        final unknown = _serviceWithProbe(mockHealth, null);
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => null);

        expect(
          await unknown.permissionStatus(),
          equals(HealthPermissionStatus.undetermined),
        );
      });
    });

    group('permissionStatus', () {
      test('is undetermined when the platform will not say', () async {
        // iOS never discloses read access; the plugin returns null.
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => null);

        expect(
          await service.permissionStatus(),
          equals(HealthPermissionStatus.undetermined),
        );
      });

      test('is undetermined when the probe throws', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenThrow(Exception('Error'));

        expect(
          await service.permissionStatus(),
          equals(HealthPermissionStatus.undetermined),
        );
      });

      test('is granted when the platform confirms access', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => true);

        expect(
          await service.permissionStatus(),
          equals(HealthPermissionStatus.granted),
        );
      });

      test('is denied when the platform refuses access', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => false);

        expect(
          await service.permissionStatus(),
          equals(HealthPermissionStatus.denied),
        );
      });

      test('is unsupported off Apple platforms', () async {
        final offPlatform = HealthKitService(
          health: mockHealth,
          isPlatformSupported: false,
        );

        expect(
          await offPlatform.permissionStatus(),
          equals(HealthPermissionStatus.unsupported),
        );
      });

      test('probes only types available on every supported iOS', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => null);

        await service.permissionStatus();

        // UNDERWATER_DEPTH is iOS 16+, and the plugin reports an unknown type
        // as an outright denial, so probing with it would make every older
        // device look permanently denied.
        final probed =
            verify(
                  mockHealth.hasPermissions(
                    captureAny,
                    permissions: anyNamed('permissions'),
                  ),
                ).captured.single
                as List<HealthDataType>;
        expect(probed, isNot(contains(HealthDataType.UNDERWATER_DEPTH)));
        expect(probed, isNot(contains(HealthDataType.WATER_TEMPERATURE)));
      });
    });

    group('hasPermissions', () {
      test('returns false when hasPermissions throws', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenThrow(Exception('Error'));

        final result = await service.hasPermissions();

        expect(result, isFalse);
      });

      test('returns false when hasPermissions returns null', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => null);

        final result = await service.hasPermissions();

        expect(result, isFalse);
      });

      test('returns true when hasPermissions returns true', () async {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => true);

        final result = await service.hasPermissions();

        expect(result, isTrue);
      });
    });

    group('requestPermissions', () {
      test('configures health and requests authorization', () async {
        when(mockHealth.configure()).thenAnswer((_) async {});
        when(
          mockHealth.requestAuthorization(
            any,
            permissions: anyNamed('permissions'),
          ),
        ).thenAnswer((_) async => true);

        final result = await service.requestPermissions();

        expect(result, isTrue);
        verify(mockHealth.configure()).called(1);
        verify(
          mockHealth.requestAuthorization(
            any,
            permissions: anyNamed('permissions'),
          ),
        ).called(1);
      });

      test('asks for the dive-specific data types', () async {
        when(mockHealth.configure()).thenAnswer((_) async {});
        when(
          mockHealth.requestAuthorization(
            any,
            permissions: anyNamed('permissions'),
          ),
        ).thenAnswer((_) async => true);

        await service.requestPermissions();

        final requested =
            verify(
                  mockHealth.requestAuthorization(
                    captureAny,
                    permissions: anyNamed('permissions'),
                  ),
                ).captured.single
                as List<HealthDataType>;
        expect(
          requested,
          containsAll([
            HealthDataType.WORKOUT,
            HealthDataType.HEART_RATE,
            HealthDataType.UNDERWATER_DEPTH,
            HealthDataType.WATER_TEMPERATURE,
          ]),
        );
      });

      test('returns false when configure throws', () async {
        when(mockHealth.configure()).thenThrow(Exception('Error'));

        final result = await service.requestPermissions();

        expect(result, isFalse);
      });

      test('returns false when requestAuthorization returns false', () async {
        when(mockHealth.configure()).thenAnswer((_) async {});
        when(
          mockHealth.requestAuthorization(
            any,
            permissions: anyNamed('permissions'),
          ),
        ).thenAnswer((_) async => false);

        final result = await service.requestPermissions();

        expect(result, isFalse);
      });
    });

    group('fetchDives', () {
      /// Stub every per-type query the service issues.
      void stubReads({
        List<HealthDataPoint> workouts = const [],
        List<HealthDataPoint> depth = const [],
        List<HealthDataPoint> temperature = const [],
        List<HealthDataPoint> heartRate = const [],
      }) {
        final byType = {
          HealthDataType.WORKOUT: workouts,
          HealthDataType.UNDERWATER_DEPTH: depth,
          HealthDataType.WATER_TEMPERATURE: temperature,
          HealthDataType.HEART_RATE: heartRate,
        };
        for (final entry in byType.entries) {
          when(
            mockHealth.getHealthDataFromTypes(
              types: [entry.key],
              startTime: anyNamed('startTime'),
              endTime: anyNamed('endTime'),
            ),
          ).thenAnswer((_) async => entry.value);
        }
      }

      void stubStatus(bool? probeResult) {
        when(
          mockHealth.hasPermissions(any, permissions: anyNamed('permissions')),
        ).thenAnswer((_) async => probeResult);
      }

      test('fetches dives when the platform will not disclose access', () async {
        // Regression for #1128: iOS never confirms read access, and gating the
        // fetch on that non-answer made Apple Watch import always come back
        // empty.
        stubStatus(null);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: DateTime(2024, 1, 15, 9, 0),
              endTime: DateTime(2024, 1, 15, 10, 0),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
        );

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, hasLength(1));
        expect(result.first.sourceId, equals('dive-uuid-123'));
      });

      test('returns empty list when the platform refuses access', () async {
        stubStatus(false);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: DateTime(2024, 1, 15, 9, 0),
              endTime: DateTime(2024, 1, 15, 10, 0),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
        );

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
        verifyNever(
          mockHealth.getHealthDataFromTypes(
            types: anyNamed('types'),
            startTime: anyNamed('startTime'),
            endTime: anyNamed('endTime'),
          ),
        );
      });

      test('returns empty list off Apple platforms', () async {
        final offPlatform = HealthKitService(
          health: mockHealth,
          isPlatformSupported: false,
        );

        final result = await offPlatform.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('returns empty list when the workout query throws', () async {
        stubStatus(true);
        stubReads();
        when(
          mockHealth.getHealthDataFromTypes(
            types: [HealthDataType.WORKOUT],
            startTime: anyNamed('startTime'),
            endTime: anyNamed('endTime'),
          ),
        ).thenThrow(Exception('Error'));

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('returns empty list when no diving workouts found', () async {
        stubStatus(true);
        stubReads();

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('filters out non-diving workouts', () async {
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'running-uuid',
              startTime: DateTime(2024, 1, 15, 10, 0),
              endTime: DateTime(2024, 1, 15, 11, 0),
              activityType: HealthWorkoutActivityType.RUNNING,
            ),
          ],
        );

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, isEmpty);
      });

      test('converts diving workouts to ImportedDive entities', () async {
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: DateTime(2024, 1, 15, 9, 0),
              endTime: DateTime(2024, 1, 15, 10, 0),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
        );

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, hasLength(1));
        expect(result.first.sourceId, equals('dive-uuid-123'));
        expect(result.first.source, equals(ImportSource.appleWatch));
        expect(result.first.startTime, equals(DateTime(2024, 1, 15, 9, 0)));
        expect(result.first.endTime, equals(DateTime(2024, 1, 15, 10, 0)));
        expect(result.first.sourceFileFormat, equals('healthkit'));
      });

      test('builds the profile from the underwater depth series', () async {
        final start = DateTime(2024, 1, 15, 9, 0);
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: start,
              endTime: start.add(const Duration(minutes: 40)),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
          depth: [
            _numericPoint(start, 0.0, HealthDataType.UNDERWATER_DEPTH),
            _numericPoint(
              start.add(const Duration(seconds: 30)),
              18.4,
              HealthDataType.UNDERWATER_DEPTH,
            ),
            _numericPoint(
              start.add(const Duration(seconds: 60)),
              9.2,
              HealthDataType.UNDERWATER_DEPTH,
            ),
          ],
        );

        final dive = (await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        )).single;

        expect(
          dive.profile.map((s) => s.timeSeconds).toList(),
          equals([0, 30, 60]),
        );
        expect(
          dive.profile.map((s) => s.depth).toList(),
          equals([0.0, 18.4, 9.2]),
        );
        expect(dive.maxDepth, equals(18.4));
        expect(dive.avgDepth, closeTo(9.2, 0.001));
      });

      test('merges temperature and heart rate onto depth samples', () async {
        final start = DateTime(2024, 1, 15, 9, 0);
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: start,
              endTime: start.add(const Duration(minutes: 40)),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
          depth: [
            _numericPoint(
              start.add(const Duration(seconds: 10)),
              12.0,
              HealthDataType.UNDERWATER_DEPTH,
            ),
            _numericPoint(
              start.add(const Duration(seconds: 600)),
              20.0,
              HealthDataType.UNDERWATER_DEPTH,
            ),
          ],
          temperature: [
            _numericPoint(
              start.add(const Duration(seconds: 12)),
              21.5,
              HealthDataType.WATER_TEMPERATURE,
            ),
          ],
          heartRate: [
            _numericPoint(
              start.add(const Duration(seconds: 8)),
              78.4,
              HealthDataType.HEART_RATE,
            ),
          ],
        );

        final dive = (await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        )).single;

        expect(dive.profile.first.temperature, equals(21.5));
        expect(dive.profile.first.heartRate, equals(78));
        // The second sample sits ten minutes from either reading, well past
        // the match window, so it must not inherit them.
        expect(dive.profile.last.temperature, isNull);
        expect(dive.profile.last.heartRate, isNull);
        expect(dive.minTemperature, equals(21.5));
        expect(dive.maxTemperature, equals(21.5));
        expect(dive.avgHeartRate, equals(78));
      });

      test('keeps the deepest reading when a second repeats', () async {
        final start = DateTime(2024, 1, 15, 9, 0);
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: start,
              endTime: start.add(const Duration(minutes: 40)),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
          depth: [
            _numericPoint(
              start.add(const Duration(seconds: 30)),
              11.0,
              HealthDataType.UNDERWATER_DEPTH,
            ),
            _numericPoint(
              start.add(const Duration(seconds: 30, milliseconds: 400)),
              14.0,
              HealthDataType.UNDERWATER_DEPTH,
            ),
          ],
        );

        final dive = (await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        )).single;

        expect(dive.profile, hasLength(1));
        expect(dive.profile.single.depth, equals(14.0));
      });

      test('falls back to heart rate alone when no depth series', () async {
        final start = DateTime(2024, 1, 15, 9, 0);
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: start,
              endTime: start.add(const Duration(minutes: 40)),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
          heartRate: [
            _numericPoint(
              start.add(const Duration(seconds: 15)),
              82.0,
              HealthDataType.HEART_RATE,
            ),
          ],
        );

        final dive = (await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        )).single;

        expect(dive.profile, hasLength(1));
        expect(dive.profile.single.depth, equals(0.0));
        expect(dive.profile.single.heartRate, equals(82));
        expect(dive.maxDepth, equals(0.0));
      });

      test('one failing series does not discard the others', () async {
        // The plugin queries types in a loop and rethrows, so an unsupported
        // type (the dive series below iOS 16) must not take the rest with it.
        final start = DateTime(2024, 1, 15, 9, 0);
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'dive-uuid-123',
              startTime: start,
              endTime: start.add(const Duration(minutes: 40)),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
          depth: [
            _numericPoint(
              start.add(const Duration(seconds: 30)),
              18.0,
              HealthDataType.UNDERWATER_DEPTH,
            ),
          ],
        );
        when(
          mockHealth.getHealthDataFromTypes(
            types: [HealthDataType.WATER_TEMPERATURE],
            startTime: anyNamed('startTime'),
            endTime: anyNamed('endTime'),
          ),
        ).thenThrow(Exception('INVALID_TYPE'));

        final dive = (await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        )).single;

        expect(dive.maxDepth, equals(18.0));
        expect(dive.minTemperature, isNull);
      });

      test('sorts dives by start time descending', () async {
        stubStatus(true);
        stubReads(
          workouts: [
            _workoutPoint(
              uuid: 'older-dive',
              startTime: DateTime(2024, 1, 10, 9, 0),
              endTime: DateTime(2024, 1, 10, 10, 0),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
            _workoutPoint(
              uuid: 'newer-dive',
              startTime: DateTime(2024, 1, 20, 9, 0),
              endTime: DateTime(2024, 1, 20, 10, 0),
              activityType: HealthWorkoutActivityType.UNDERWATER_DIVING,
            ),
          ],
        );

        final result = await service.fetchDives(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        );

        expect(result, hasLength(2));
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

/// A service whose device-capability probe returns [available].
HealthKitService _serviceWithProbe(MockHealth health, bool? available) {
  return HealthKitService(
    health: health,
    isPlatformSupported: true,
    healthDataAvailable: () async => available,
  );
}

/// Helper to create a workout data point for testing.
HealthDataPoint _workoutPoint({
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

/// Helper to create a numeric sample (depth, temperature, or heart rate).
HealthDataPoint _numericPoint(DateTime at, double value, HealthDataType type) {
  return HealthDataPoint(
    uuid: '${type.name}-${at.microsecondsSinceEpoch}',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: dataTypeToUnit[type] ?? HealthDataUnit.NO_UNIT,
    dateFrom: at,
    dateTo: at,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'apple-watch',
    sourceId: 'com.apple.health',
    sourceName: 'Apple Watch',
  );
}
