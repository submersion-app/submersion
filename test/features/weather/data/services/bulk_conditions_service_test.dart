import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/weather/data/services/bulk_conditions_service.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';

import '../../../../helpers/test_database.dart';

/// A canned Open-Meteo archive payload. Every hour of the day carries the same
/// values, so a test never has to care which hour the mapper picks.
String _payload({double temp = 27.0, double windKmh = 18.0}) {
  final times = [
    for (var h = 0; h < 24; h++)
      '2024-06-15T${h.toString().padLeft(2, '0')}:00',
  ];
  return jsonEncode({
    'hourly': {
      'time': times,
      'temperature_2m': [for (var _ in times) temp],
      'relative_humidity_2m': [for (var _ in times) 70.0],
      'precipitation': [for (var _ in times) 0.0],
      'cloud_cover': [for (var _ in times) 10.0],
      'wind_speed_10m': [for (var _ in times) windKmh],
      'wind_direction_10m': [for (var _ in times) 90.0],
      'surface_pressure': [for (var _ in times) 1013.0],
      'weathercode': [for (var _ in times) 0],
    },
  });
}

/// A payload whose temperature is the hour number, so an assertion on the
/// filled air temperature says which hour the mapper picked.
String _payloadTempPerHour() {
  final times = [
    for (var h = 0; h < 24; h++)
      '2024-06-15T${h.toString().padLeft(2, '0')}:00',
  ];
  return jsonEncode({
    'hourly': {
      'time': times,
      'temperature_2m': [for (var h = 0; h < 24; h++) h.toDouble()],
      'relative_humidity_2m': [for (var _ in times) 70.0],
      'precipitation': [for (var _ in times) 0.0],
      'cloud_cover': [for (var _ in times) 10.0],
      'wind_speed_10m': [for (var _ in times) 18.0],
      'wind_direction_10m': [for (var _ in times) 90.0],
      'surface_pressure': [for (var _ in times) 1013.0],
      'weathercode': [for (var _ in times) 0],
    },
  });
}

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id, double lat, double lon) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            createdAt: now,
            updatedAt: now,
            latitude: Value(lat),
            longitude: Value(lon),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    required String siteId,
    required DateTime at,
    DivesCompanion weather = const DivesCompanion(),
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: at.millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
            siteId: Value(siteId),
            windSpeed: weather.windSpeed,
            humidity: weather.humidity,
            airTemp: weather.airTemp,
          ),
        );
  }

  /// A dive whose only empty fillable column is airTemp.
  Future<void> insertDiveMissingOnlyAirTemp(
    String id, {
    required String siteId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: DateTime.utc(2024, 6, 15, 10).millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
            siteId: Value(siteId),
            windSpeed: const Value(4.0),
            windDirection: const Value('north'),
            cloudCover: const Value('clear'),
            precipitation: const Value('none'),
            humidity: const Value(70.0),
            weatherCode: const Value(0),
            surfacePressure: const Value(1.013),
          ),
        );
  }

  /// Builds a service whose HTTP layer records every URL it is asked for.
  ({BulkConditionsService service, List<Uri> requests}) buildService({
    http.Response Function(http.Request request)? respond,
  }) {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return respond?.call(request) ?? http.Response(_payload(), 200);
    });
    return (
      service: BulkConditionsService(
        diveRepository: repository,
        weatherService: WeatherService(client: client),
        requestDelay: Duration.zero,
      ),
      requests: requests,
    );
  }

  Future<Dive> readRow(String id) async =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  group('diveWallClockToLocal', () {
    test('rebuilds the stored wall clock in the local zone', () {
      // Dive times are stored as a wall clock flagged UTC. The archive mapper
      // compares against locally parsed timestamps, so the same components
      // have to be rebuilt locally or the sampled hour is off by the machine's
      // UTC offset.
      final local = diveWallClockToLocal(DateTime.utc(2024, 6, 15, 9, 30));

      expect(local.isUtc, isFalse);
      expect(local.year, 2024);
      expect(local.month, 6);
      expect(local.day, 15);
      expect(local.hour, 9);
      expect(local.minute, 30);
    });
  });

  group('BulkConditionsService.countCandidates', () {
    test('counts only dives that can be filled', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertSite('s2', 0, 0);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 10));
      await insertDive('d2', siteId: 's2', at: DateTime.utc(2024, 6, 15, 10));

      final (:service, :requests) = buildService();

      expect(await service.countCandidates(), 2);
      expect(requests, isEmpty, reason: 'counting must not hit the network');
    });
  });

  group('BulkConditionsService.run', () {
    test('fills conditions for every candidate dive', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 10));

      final (:service, :requests) = buildService();
      final result = await service.run();

      expect(result.filled, 1);
      final row = await readRow('d1');
      expect(row.humidity, 70.0);
      expect(row.airTemp, 27.0);
      expect(row.weatherCode, 0);
    });

    test('samples the hour the diver entered the water', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));

      final (:service, :requests) = buildService(
        respond: (_) => http.Response(_payloadTempPerHour(), 200),
      );
      await service.run();

      // The payload's temperature is the hour number, so 9.0 means the 09:00
      // sample was chosen rather than one shifted by the machine's UTC offset.
      expect((await readRow('d1')).airTemp, 9.0);
    });

    test('paces the requests it makes when a delay is configured', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', siteId: 's1', at: DateTime.utc(2024, 6, 16, 9));

      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        return http.Response(_payload(), 200);
      });
      final service = BulkConditionsService(
        diveRepository: repository,
        weatherService: WeatherService(client: client),
        requestDelay: const Duration(milliseconds: 1),
      );

      final result = await service.run();

      expect(requests, hasLength(2));
      expect(result.filled, 2);
    });

    test('does not sit through the pacing delay once cancelled', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', siteId: 's1', at: DateTime.utc(2024, 6, 16, 9));

      // Cancel arrives while the first request is in flight, which is what a
      // diver tapping the button actually does.
      var cancelled = false;
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        cancelled = true;
        return http.Response(_payload(), 200);
      });
      final service = BulkConditionsService(
        diveRepository: repository,
        weatherService: WeatherService(client: client),
        // Long enough that waiting it out hangs the test rather than passing
        // slowly: the pacing exists to space out the NEXT request, and a
        // cancelled run has no next request to space out.
        requestDelay: const Duration(minutes: 5),
      );

      final result = await service.run(isCancelled: () => cancelled);

      expect(result.cancelled, isTrue);
      expect(result.filled, 1);
      expect(requests, hasLength(1));
    });

    test('processed counts every bucket the run filled out', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertSite('s2', 36.7, -4.4);
      await insertDive('d2', siteId: 's2', at: DateTime.utc(2024, 6, 15, 9));

      final (:service, :requests) = buildService(
        respond: (request) => request.url.queryParameters['latitude'] == '12.5'
            ? http.Response('{}', 500)
            : http.Response(_payload(), 200),
      );
      final result = await service.run();

      expect(result.filled, 1);
      expect(result.unavailable, 1);
      expect(result.processed, 2);
    });

    test('reuses one response for dives sharing a site and a day', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', siteId: 's1', at: DateTime.utc(2024, 6, 15, 11));
      await insertDive('d3', siteId: 's1', at: DateTime.utc(2024, 6, 15, 14));

      final (:service, :requests) = buildService();
      final result = await service.run();

      expect(result.filled, 3);
      expect(requests, hasLength(1));
    });

    test('fetches separately for the same site on a different day', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', siteId: 's1', at: DateTime.utc(2024, 6, 16, 9));

      final (:service, :requests) = buildService();
      await service.run();

      expect(requests, hasLength(2));
    });

    test('fetches separately for different sites on the same day', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertSite('s2', 36.7, -4.4);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', siteId: 's2', at: DateTime.utc(2024, 6, 15, 9));

      final (:service, :requests) = buildService();
      await service.run();

      expect(requests, hasLength(2));
    });

    test('never overwrites a value the diver already entered', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive(
        'd1',
        siteId: 's1',
        at: DateTime.utc(2024, 6, 15, 10),
        weather: const DivesCompanion(airTemp: Value(19.0)),
      );

      final (:service, :requests) = buildService();
      await service.run();

      final row = await readRow('d1');
      expect(row.airTemp, 19.0);
      expect(row.humidity, 70.0);
    });

    test(
      'counts a dive as unavailable when the provider has no data',
      () async {
        await insertSite('s1', 12.5, -68.25);
        await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 10));

        final (:service, :requests) = buildService(
          respond: (_) => http.Response('{}', 500),
        );
        final result = await service.run();

        expect(result.filled, 0);
        expect(result.unavailable, 1);
        final row = await readRow('d1');
        expect(row.humidity, isNull);
      },
    );

    test('a failed day does not abort the remaining dives', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertSite('s2', 36.7, -4.4);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 10));
      await insertDive('d2', siteId: 's2', at: DateTime.utc(2024, 6, 15, 10));

      final (:service, :requests) = buildService(
        respond: (request) => request.url.queryParameters['latitude'] == '12.5'
            ? http.Response('{}', 500)
            : http.Response(_payload(), 200),
      );
      final result = await service.run();

      expect(result.unavailable, 1);
      expect(result.filled, 1);
      expect((await readRow('d2')).humidity, 70.0);
    });

    test('reports progress for each dive processed', () async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', siteId: 's1', at: DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', siteId: 's1', at: DateTime.utc(2024, 6, 16, 9));

      final (:service, :requests) = buildService();
      final seen = <int>[];
      await service.run(onProgress: (p) => seen.add(p.completed));

      expect(seen, [1, 2]);
    });

    test(
      'stops fetching once cancelled and reports the cancellation',
      () async {
        await insertSite('s1', 12.5, -68.25);
        for (var i = 0; i < 5; i++) {
          await insertDive(
            'd$i',
            siteId: 's1',
            at: DateTime.utc(2024, 6, 15 + i, 9),
          );
        }

        final (:service, :requests) = buildService();
        var cancelled = false;
        final result = await service.run(
          onProgress: (p) {
            if (p.completed >= 2) cancelled = true;
          },
          isCancelled: () => cancelled,
        );

        expect(result.cancelled, isTrue);
        expect(result.filled, 2);
        expect(requests, hasLength(2));
      },
    );

    test('counts a dive as unchanged when the one gap has no value', () async {
      await insertSite('s1', 12.5, -68.25);
      // Only airTemp is empty, and the archive has no temperature for this
      // place and day, so the fetch succeeds but fills nothing.
      await insertDiveMissingOnlyAirTemp('d1', siteId: 's1');

      final (:service, :requests) = buildService(
        respond: (_) => http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2024-06-15T10:00'],
              'temperature_2m': [null],
              'relative_humidity_2m': [70.0],
              'precipitation': [0.0],
              'cloud_cover': [10.0],
              'wind_speed_10m': [18.0],
              'wind_direction_10m': [90.0],
              'surface_pressure': [1013.0],
              'weathercode': [0],
            },
          }),
          200,
        ),
      );
      final result = await service.run();

      expect(result.filled, 0);
      expect(result.unchanged, 1);
    });
  });
}
