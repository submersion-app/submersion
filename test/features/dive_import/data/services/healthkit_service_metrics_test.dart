import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/data/services/healthkit_service.dart';

import 'healthkit_service_test.mocks.dart';

/// Heart rate, heart rate variability and sleep read from Apple Health for a
/// dive's health record (issue #637).
void main() {
  late MockHealth health;
  late HealthKitService service;
  final start = DateTime.utc(2026, 7, 17, 10);
  final end = DateTime.utc(2026, 7, 17, 11);

  setUp(() {
    health = MockHealth();
    service = HealthKitService(health: health, isPlatformSupported: true);
  });

  HealthDataPoint point(
    HealthDataType type,
    DateTime from,
    DateTime to, {
    double value = 0,
  }) => HealthDataPoint(
    uuid: '${type.name}-${from.microsecondsSinceEpoch}',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: dataTypeToUnit[type] ?? HealthDataUnit.NO_UNIT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'apple-watch',
    sourceId: 'com.apple.health',
    sourceName: 'Apple Watch',
  );

  void answer(HealthDataType type, List<HealthDataPoint> points) => when(
    health.getHealthDataFromTypes(
      types: [type],
      startTime: anyNamed('startTime'),
      endTime: anyNamed('endTime'),
    ),
  ).thenAnswer((_) async => points);

  test('heart rate comes back as UTC samples in time order', () async {
    final later = DateTime(2026, 7, 17, 10, 5);
    final earlier = DateTime(2026, 7, 17, 10, 1);
    answer(HealthDataType.HEART_RATE, [
      point(HealthDataType.HEART_RATE, later, later, value: 75),
      point(HealthDataType.HEART_RATE, earlier, earlier, value: 82),
    ]);

    final samples = await service.fetchHeartRate(start: start, end: end);

    expect(samples.map((s) => s.value), [82, 75]);
    expect(samples.first.at, earlier.toUtc());
    expect(samples.first.at.isUtc, isTrue);
  });

  test('heart rate variability reads the SDNN series', () async {
    answer(HealthDataType.HEART_RATE_VARIABILITY_SDNN, [
      point(
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        start,
        start,
        value: 48.5,
      ),
    ]);

    final samples = await service.fetchHrv(start: start, end: end);

    expect(samples.single.value, 48.5);
  });

  test('sleep comes back as asleep intervals', () async {
    final night = DateTime.utc(2026, 7, 16, 23);
    answer(HealthDataType.SLEEP_ASLEEP, [
      point(
        HealthDataType.SLEEP_ASLEEP,
        night,
        night.add(const Duration(hours: 4)),
      ),
    ]);

    final sleep = await service.fetchSleep(start: start, end: end);

    expect(sleep.single.start, night);
    expect(sleep.single.end, night.add(const Duration(hours: 4)));
  });

  test(
    'sleep the watch logs as stages is read too (watchOS 9 and later)',
    () async {
      final night = DateTime.utc(2026, 7, 16, 23);
      answer(HealthDataType.SLEEP_ASLEEP, const []);
      answer(HealthDataType.SLEEP_LIGHT, [
        point(
          HealthDataType.SLEEP_LIGHT,
          night,
          night.add(const Duration(hours: 2)),
        ),
      ]);
      answer(HealthDataType.SLEEP_DEEP, [
        point(
          HealthDataType.SLEEP_DEEP,
          night.add(const Duration(hours: 2)),
          night.add(const Duration(hours: 3)),
        ),
      ]);
      answer(HealthDataType.SLEEP_REM, const []);

      final sleep = await service.fetchSleep(start: start, end: end);

      expect(sleep.map((s) => s.start), [
        night,
        night.add(const Duration(hours: 2)),
      ]);
    },
  );

  test('asking for the readings asks for the sleep stages too', () async {
    when(health.configure()).thenAnswer((_) async {});
    when(
      health.requestAuthorization(any, permissions: anyNamed('permissions')),
    ).thenAnswer((_) async => true);
    final withProbe = HealthKitService(
      health: health,
      isPlatformSupported: true,
      healthDataAvailable: () async => true,
    );

    await withProbe.requestMetricsPermissions();

    final types =
        verify(
              health.requestAuthorization(
                captureAny,
                permissions: anyNamed('permissions'),
              ),
            ).captured.single
            as List<HealthDataType>;
    expect(
      types,
      containsAll([
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
      ]),
    );
  });

  test('a refused read gives nothing rather than failing', () async {
    when(
      health.getHealthDataFromTypes(
        types: anyNamed('types'),
        startTime: anyNamed('startTime'),
        endTime: anyNamed('endTime'),
      ),
    ).thenThrow(Exception('denied'));

    expect(await service.fetchHeartRate(start: start, end: end), isEmpty);
    expect(await service.fetchSleep(start: start, end: end), isEmpty);
  });
}
