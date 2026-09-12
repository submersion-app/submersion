import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';

import '../../../../helpers/test_database.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/nav_tracks/$name').readAsBytesSync();

void main() {
  late AppDatabase db;
  late NavTrackRepository routeRepo;
  late DiveRepository diveRepo;
  late NavTrackImportService service;

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
    routeRepo = NavTrackRepository();
    diveRepo = DiveRepository();
    service = NavTrackImportService(
      routeRepository: routeRepo,
      diveRepository: diveRepo,
      matchService: NavTrackMatchService(
        routeRepository: routeRepo,
        diveRepository: diveRepo,
      ),
    );
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id, int diveDateTimeMs, {int? exitTimeMs}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: diveDateTimeMs,
          exitTime: Value(exitTimeMs),
          createdAt: diveDateTimeMs,
          updatedAt: diveDateTimeMs,
        ),
      );

  group('prepare', () {
    test('parses a real ENC3 fixture and reports its stats', () async {
      final preview = await service.prepare(
        _fixture('seacraft_enc3_real.csv'),
        fileName: '008.DAT.csv',
      );

      expect(preview.parsed.points, isNotEmpty);
      expect(preview.stats.pointCount, preview.parsed.points.length);
      expect(preview.stats.maxDepth, greaterThan(30));
      expect(preview.sourceRef, '008.DAT.csv');
      expect(preview.duplicateOfRouteId, isNull);
    });

    test('flags a bench-test recording as having no movement', () async {
      final preview = await service.prepare(
        _fixture('seacraft_enc3_bench.csv'),
        fileName: '002.DAT.csv',
      );
      expect(preview.hasNoMovement, isTrue);
    });

    test('proposes the unique overlapping dive as a link candidate', () async {
      // The short fixture starts 15.1.2025 16:16:07 local-as-UTC.
      final routeStart = DateTime.utc(2025, 1, 15, 16, 16, 7);
      await seedDive(
        'd1',
        routeStart.millisecondsSinceEpoch,
        exitTimeMs: routeStart
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      );

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.candidateDives.map((d) => d.id), ['d1']);
    });

    test('reports no duplicate for a fresh import', () async {
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      expect(preview.duplicateOfRouteId, isNull);
    });

    test('flags a duplicate: same source file already stored, overlapping '
        'window', () async {
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      final firstId = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
      );

      final reimport = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      expect(reimport.duplicateOfRouteId, firstId);
    });

    test(
      'throws NavTrackParseException with reason on an unreadable file',
      () async {
        expect(
          () => service.prepare(
            Uint8List.fromList('not,a,route\n1,2,3'.codeUnits),
            fileName: 'bad.csv',
          ),
          throwsA(
            isA<NavTrackParseException>().having(
              (e) => e.reason,
              'reason',
              NavTrackParseReason.unreadable,
            ),
          ),
        );
      },
    );
  });

  group('commit', () {
    test('writes the route unlinked and runs the sweep when no dive was '
        'chosen', () async {
      final routeStart = DateTime.utc(2025, 1, 15, 16, 16, 7);
      await seedDive(
        'd1',
        routeStart.millisecondsSinceEpoch,
        exitTimeMs: routeStart
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      );
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      final id = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
      );

      final route = await routeRepo.getById(id);
      // The sweep found the single overlapping dive and linked it, even
      // though the diver made no explicit choice on the review page.
      expect(route!.diveId, 'd1');
      expect(route.linkMode, isNotNull);
    });

    test('links directly and skips the sweep when a dive was chosen', () async {
      await seedDive('d1', 1000000, exitTimeMs: 1100000);
      await seedDive('d2', 1000000, exitTimeMs: 1100000);
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      final chosenDive = await diveRepo.getDiveById('d1');

      final id = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
        dive: chosenDive,
      );

      final route = await routeRepo.getById(id);
      expect(route!.diveId, 'd1');
    });

    test('anchors the route to the given site', () async {
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Test Site', 1, 1)",
      );
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      final id = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
        siteId: 's1',
      );

      final route = await routeRepo.getById(id);
      expect(route!.siteId, 's1');
    });

    test('persists the chosen equipment id', () async {
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, updated_at) "
        "VALUES ('eq1', NULL, 'Test Scooter', 'dpv', 1, 1)",
      );
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      final id = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
        equipmentId: 'eq1',
      );

      final route = await routeRepo.getById(id);
      expect(route!.equipmentId, 'eq1');
    });

    test('leaves equipmentId null when no equipment was chosen', () async {
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      final id = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
      );

      final route = await routeRepo.getById(id);
      expect(route!.equipmentId, isNull);
    });
  });
}
