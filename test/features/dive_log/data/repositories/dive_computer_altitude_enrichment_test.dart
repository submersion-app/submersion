import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

import '../../../../helpers/test_database.dart';

/// A batch dive-computer download runs [DiveComputerRepository.importProfile]
/// once per dive. The repository holds a single [DiveAltitudeEnricher] so the
/// elevation lookup is shared across the batch rather than repeated (and, on a
/// slow network, waited on) for every dive.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late List<Uri> requests;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    requests = <Uri>[];
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  DiveComputerRepository repositoryWith({bool fail = false}) {
    return DiveComputerRepository(
      altitudeEnricher: DiveAltitudeEnricher(
        elevationService: ElevationService(
          client: MockClient((request) async {
            requests.add(request.url);
            if (fail) return http.Response('oops', 500);
            return http.Response(
              jsonEncode({
                'elevation': [740.2],
              }),
              200,
            );
          }),
        ),
        diveRepository: dives,
      ),
    );
  }

  Future<String> insertComputer() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('computer-1'),
            name: const Value('Shearwater Perdix'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix'),
            serialNumber: const Value('SN-12345'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return 'computer-1';
  }

  Future<String> importDive(
    DiveComputerRepository repository,
    String computerId,
    DateTime start,
  ) {
    return repository.importProfile(
      computerId: computerId,
      profileStartTime: start,
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0),
        ProfilePointData(timestamp: 60, depth: 12.0),
      ],
      durationSeconds: 40 * 60,
      maxDepth: 20.0,
      forceNew: true,
      entryLatitude: 46.4,
      entryLongitude: 8.0,
    );
  }

  test('a batch download at one location does a single lookup', () async {
    final computerId = await insertComputer();
    final repository = repositoryWith();

    final ids = <String>[];
    for (var i = 0; i < 4; i++) {
      ids.add(
        await importDive(
          repository,
          computerId,
          DateTime(2026, 3, 15, 10 + i, 0),
        ),
      );
    }

    expect(requests, hasLength(1));
    for (final id in ids) {
      final dive = await dives.getDiveById(id);
      expect(dive!.altitude, 740.0);
    }
  });

  test(
    'a failing lookup is not retried per dive and imports succeed',
    () async {
      final computerId = await insertComputer();
      final repository = repositoryWith(fail: true);

      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        ids.add(
          await importDive(
            repository,
            computerId,
            DateTime(2026, 3, 15, 10 + i, 0),
          ),
        );
      }

      expect(requests, hasLength(1));
      for (final id in ids) {
        final dive = await dives.getDiveById(id);
        expect(dive, isNotNull);
        expect(dive!.altitude, isNull);
      }
    },
  );
}
