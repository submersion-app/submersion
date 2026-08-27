import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive(String id, {GeoPoint? entryLocation, double? altitude}) =>
      Dive(
        id: id,
        diveNumber: 1,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        entryLocation: entryLocation,
        altitude: altitude,
        tanks: const [],
        profile: const [],
        equipment: const [],
        notes: '',
        photoIds: const [],
        sightings: const [],
        weights: const [],
        tags: const [],
      );

  ElevationService countingService(List<Uri> requests) => ElevationService(
    client: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode({
          'elevation': [740.2],
        }),
        200,
      );
    }),
  );

  test('fills altitude for an imported dive with GPS', () async {
    final dive = await repository.createDive(
      buildDive('d1', entryLocation: const GeoPoint(46.4, 8.0)),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService([]),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isTrue);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, 740.0);
  });

  test('skips dives that already have altitude', () async {
    final requests = <Uri>[];
    final dive = await repository.createDive(
      buildDive('d2', entryLocation: const GeoPoint(46.4, 8.0), altitude: 500),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService(requests),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isFalse);
    expect(requests, isEmpty);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, 500.0);
  });

  test('skips dives with no GPS and no site', () async {
    final requests = <Uri>[];
    final dive = await repository.createDive(buildDive('d3'));
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService(requests),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isFalse);
    expect(requests, isEmpty);
  });

  test('one lookup covers a batch at the same location', () async {
    final requests = <Uri>[];
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService(requests),
      diveRepository: repository,
    );

    for (var i = 0; i < 3; i++) {
      final dive = await repository.createDive(
        buildDive('batch-$i', entryLocation: const GeoPoint(46.4, 8.0)),
      );
      await enricher.applyForImportedDive(dive);
    }

    expect(requests, hasLength(1));
    final stored = await repository.getDiveById('batch-2');
    expect(stored!.altitude, 740.0);
  });

  test('lookup failure leaves the dive importable and unchanged', () async {
    final dive = await repository.createDive(
      buildDive('d4', entryLocation: const GeoPoint(46.4, 8.0)),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: ElevationService(
        client: MockClient((_) async => http.Response('oops', 500)),
      ),
      diveRepository: repository,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isFalse);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, isNull);
  });

  test('fills a downloaded dive from its GPS points', () async {
    final dive = await repository.createDive(buildDive('d5'));
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService([]),
      diveRepository: repository,
    );

    final applied = await enricher.applyForDownloadedDive(
      diveId: dive.id,
      points: const [GeoPoint(46.4, 8.0)],
    );

    expect(applied, isTrue);
    final stored = await repository.getDiveById(dive.id);
    expect(stored!.altitude, 740.0);
  });

  test('downloaded dive with no points is a no-op', () async {
    final dive = await repository.createDive(buildDive('d6'));
    final enricher = DiveAltitudeEnricher(
      elevationService: countingService([]),
      diveRepository: repository,
    );

    final applied = await enricher.applyForDownloadedDive(
      diveId: dive.id,
      points: const [],
    );

    expect(applied, isFalse);
  });
}
