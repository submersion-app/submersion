import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_csv_parser.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

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
    );
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<void> seedDive(
    String id,
    int diveDateTimeMs, {
    int? exitTimeMs,
    String? diverId,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diverId),
          diveDateTime: diveDateTimeMs,
          exitTime: Value(exitTimeMs),
          createdAt: diveDateTimeMs,
          updatedAt: diveDateTimeMs,
        ),
      );

  group('scoped to the active diver', () {
    late NavTrackImportService mine;
    final routeStart = DateTime.utc(2025, 1, 15, 16, 16, 7);

    setUp(() async {
      for (final id in ['me', 'buddy']) {
        await db.customStatement(
          "INSERT INTO divers (id, name, created_at, updated_at) "
          "VALUES ('$id', '$id', 1, 1)",
        );
      }
      mine = NavTrackImportService(
        routeRepository: routeRepo,
        diveRepository: diveRepo,
        currentDiverId: () async => 'me',
      );
    });

    test('proposes only the active diver\'s overlapping dive', () async {
      for (final (id, diver) in [('my-dive', 'me'), ('buddy-dive', 'buddy')]) {
        await seedDive(
          id,
          routeStart.millisecondsSinceEpoch,
          exitTimeMs: routeStart
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          diverId: diver,
        );
      }

      final preview = await mine.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.candidateDives.map((d) => d.id), ['my-dive']);
    });

    test('offers only the active diver\'s dives as nearest', () async {
      final earlier = routeStart.subtract(const Duration(hours: 2));
      await seedDive(
        'buddy-dive',
        earlier.millisecondsSinceEpoch,
        diverId: 'buddy',
      );
      await seedDive(
        'my-dive',
        earlier.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        diverId: 'me',
      );

      final preview = await mine.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.candidateDives, isEmpty);
      expect(preview.nearbyDives.map((d) => d.id), ['my-dive']);
    });

    test(
      'never flags another diver\'s route as the duplicate to replace',
      () async {
        final buddy = NavTrackImportService(
          routeRepository: routeRepo,
          diveRepository: diveRepo,
          currentDiverId: () async => 'buddy',
        );
        final first = await buddy.prepare(
          _fixture('seacraft_enc3_short.csv'),
          fileName: '005.DAT.csv',
        );
        await buddy.commit(
          parsed: first.parsed,
          sourceRef: first.sourceRef,
          diverId: first.diverId,
        );

        final preview = await mine.prepare(
          _fixture('seacraft_enc3_short.csv'),
          fileName: '005.DAT.csv',
        );

        expect(preview.duplicateOfRouteId, isNull);
      },
    );

    test('a profile switch during review changes neither the proposal\'s '
        'scope nor the saved route\'s owner', () async {
      var active = 'me';
      final switching = NavTrackImportService(
        routeRepository: routeRepo,
        diveRepository: diveRepo,
        currentDiverId: () async => active,
      );
      final preview = await switching.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      expect(preview.diverId, 'me');

      active = 'buddy';
      final id = await switching.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
        diverId: preview.diverId,
      );

      final owner = await db
          .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$id'")
          .getSingle();
      expect(owner.read<String?>('diver_id'), 'me');
    });

    test('an unlinked route belongs to the diver who imported it', () async {
      final preview = await mine.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      final id = await mine.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
        diverId: preview.diverId,
      );

      final owner = await db
          .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$id'")
          .getSingle();
      expect(owner.read<String?>('diver_id'), 'me');
    });
  });

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
      // An overlap match is the whole proposal; the nearest-dive fallback
      // is only for a recording nothing overlaps.
      expect(preview.nearbyDives, isEmpty);
    });

    test('offers the nearest dives by start time when no dive overlaps, '
        'e.g. a recording console clock set 2 hours ahead', () async {
      // The short fixture starts 15.1.2025 16:16:07 local-as-UTC; the dives
      // were logged by a dive computer 2 hours behind the console.
      final routeStart = DateTime.utc(2025, 1, 15, 16, 16, 7);
      final twoHoursEarlier = routeStart.subtract(const Duration(hours: 2));
      await seedDive(
        'right-dive',
        twoHoursEarlier.millisecondsSinceEpoch,
        exitTimeMs: twoHoursEarlier
            .add(const Duration(minutes: 50))
            .millisecondsSinceEpoch,
      );
      final dayBefore = routeStart.subtract(const Duration(days: 1));
      await seedDive(
        'day-before',
        dayBefore.millisecondsSinceEpoch,
        exitTimeMs: dayBefore
            .add(const Duration(minutes: 50))
            .millisecondsSinceEpoch,
      );

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.candidateDives, isEmpty);
      expect(preview.nearbyDives.map((d) => d.id), [
        'right-dive',
        'day-before',
      ]);
    });

    test('offers nothing when the log has no dives at all', () async {
      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );
      expect(preview.candidateDives, isEmpty);
      expect(preview.nearbyDives, isEmpty);
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
        diverId: preview.diverId,
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
    test(
      'keeps the route unlinked when no dive was chosen, even with one '
      'overlapping dive (the review page\'s "Leave unlinked" choice)',
      () async {
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
        // The review page proposes the unique match itself; getting here with
        // no dive means the diver turned that proposal down.
        expect(preview.candidateDives.map((d) => d.id), ['d1']);

        final id = await service.commit(
          parsed: preview.parsed,
          sourceRef: preview.sourceRef,
          diverId: preview.diverId,
        );

        final route = await routeRepo.getById(id);
        expect(route!.diveId, isNull);
        expect(route.linkMode, isNull);
      },
    );

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
        diverId: preview.diverId,
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
        diverId: preview.diverId,
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
        diverId: preview.diverId,
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
        diverId: preview.diverId,
      );

      final route = await routeRepo.getById(id);
      expect(route!.equipmentId, isNull);
    });
  });

  group('original file (issue #4231)', () {
    test('commit stores the file with the route', () async {
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');
      final preview = await service.prepare(bytes, fileName: '011.DAT.csv');

      final id = await service.commit(
        parsed: preview.parsed,
        sourceRef: preview.sourceRef,
        diverId: preview.diverId,
        sourceFile: bytes,
      );

      expect(await routeRepo.getSourceFile(id), bytes);
      final route = (await routeRepo.getById(id))!;
      expect(await routeRepo.getMarkers(route), hasLength(2));
    });
  });

  group('duplicate window (issue #4231)', () {
    /// The short fixture's recording, shifted by [offset].
    Future<String> storeShifted(Duration offset) {
      final points = [
        for (final p in parseSeacraftEncCsv(
          _fixture('seacraft_enc3_short.csv'),
        ).points)
          p.copyWith(timestamp: p.timestamp + offset.inSeconds),
      ];
      return routeRepo.insertImportedRoute(
        points: points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: '005.DAT.csv',
      );
    }

    test('flags a file of the same name recorded days apart', () async {
      final storedId = await storeShifted(const Duration(days: 6));

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.duplicateOfRouteId, storedId);
      // Not the same recording, so the review does not propose updating it.
      expect(preview.duplicateIsSameRecording, isFalse);
    });

    test('the same recording read again is flagged as such', () async {
      final storedId = await storeShifted(Duration.zero);

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.duplicateOfRouteId, storedId);
      expect(preview.duplicateIsSameRecording, isTrue);
    });

    test('never offers a route of another source for an update', () async {
      await routeRepo.insertImportedRoute(
        points: parseSeacraftEncCsv(_fixture('seacraft_enc3_short.csv')).points,
        source: NavTrackSource.suuntoRoute,
        sourceRef: '005.DAT.csv',
      );

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.duplicateOfRouteId, isNull);
    });

    test(
      'prefers the same recording over a nearby one of the same name',
      () async {
        await storeShifted(const Duration(days: 2));
        final sameId = await storeShifted(Duration.zero);

        final preview = await service.prepare(
          _fixture('seacraft_enc3_short.csv'),
          fileName: '005.DAT.csv',
        );

        expect(preview.duplicateOfRouteId, sameId);
        expect(preview.duplicateIsSameRecording, isTrue);
      },
    );

    test(
      'a file of the same name recorded weeks apart is a new route',
      () async {
        await storeShifted(const Duration(days: 30));

        final preview = await service.prepare(
          _fixture('seacraft_enc3_short.csv'),
          fileName: '005.DAT.csv',
        );

        expect(preview.duplicateOfRouteId, isNull);
      },
    );

    test('a long stored recording whose end comes near but whose start lies '
        'outside the window is a new route', () async {
      // Started nine days before this recording and ran for six days, so
      // its end is three days away: the window is about start times.
      final start = parseSeacraftEncCsv(
        _fixture('seacraft_enc3_short.csv'),
      ).points.first.timestamp;
      await routeRepo.insertImportedRoute(
        points: [
          NavTrackPoint(
            timestamp: start - const Duration(days: 9).inSeconds,
            north: 0,
            east: 0,
            depth: 2,
          ),
          NavTrackPoint(
            timestamp: start - const Duration(days: 3).inSeconds,
            north: 5,
            east: 0,
            depth: 2,
          ),
        ],
        source: NavTrackSource.seacraftEnc,
        sourceRef: '005.DAT.csv',
      );

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.duplicateOfRouteId, isNull);
    });

    test('a file of another name in the same window is a new route', () async {
      await routeRepo.insertImportedRoute(
        points: parseSeacraftEncCsv(_fixture('seacraft_enc3_short.csv')).points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: '006.DAT.csv',
      );

      final preview = await service.prepare(
        _fixture('seacraft_enc3_short.csv'),
        fileName: '005.DAT.csv',
      );

      expect(preview.duplicateOfRouteId, isNull);
    });
  });

  group('updateFromFile (issue #4231)', () {
    test('replaces the data and keeps the dive link, site and name', () async {
      await seedDive('d1', 1000000, exitTimeMs: 1100000);
      final dive = await diveRepo.getDiveById('d1');
      final first = await service.prepare(
        _fixture('seacraft_enc3_real.csv'),
        fileName: '011.DAT.csv',
      );
      final id = await service.commit(
        parsed: first.parsed,
        sourceRef: first.sourceRef,
        diverId: first.diverId,
        dive: dive,
        name: 'Kept name',
      );
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');
      final again = await service.prepare(bytes, fileName: '011.DAT.csv');

      final updated = await service.updateFromFile(
        routeId: id,
        parsed: again.parsed,
        sourceFile: bytes,
      );

      expect(updated, isTrue);
      final route = (await routeRepo.getById(id))!;
      expect(route.diveId, 'd1');
      expect(route.name, 'Kept name');
      expect(route.pointCount, again.parsed.points.length);
      expect(await routeRepo.getSourceFile(id), bytes);
      // Updating never creates a second route.
      expect(await routeRepo.getAll(), hasLength(1));
    });

    test('records the new file name and its markers', () async {
      final first = await service.prepare(
        _fixture('seacraft_enc3_real.csv'),
        fileName: '008.DAT.csv',
      );
      final id = await service.commit(
        parsed: first.parsed,
        sourceRef: first.sourceRef,
        diverId: first.diverId,
      );
      final bytes = _fixture('seacraft_enc3_gps_fix.csv');

      final updated = await service.updateFromFile(
        routeId: id,
        parsed: service.parseFile(bytes),
        sourceFile: bytes,
        sourceRef: '011.DAT.csv',
      );

      expect(updated, isTrue);
      final route = (await routeRepo.getById(id))!;
      expect(route.sourceRef, '011.DAT.csv');
      expect((await routeRepo.getMarkers(route)).map((m) => m.rawValue), [
        -1,
        -101,
      ]);
    });

    test('parseFile rejects a file it cannot read', () {
      expect(
        () => service.parseFile(
          Uint8List.fromList('not,a,route\n1,2,3'.codeUnits),
        ),
        throwsA(isA<NavTrackParseException>()),
      );
    });

    test('isSameRecording tells the route\'s own recording from another '
        'one of the same name', () async {
      final bytes = _fixture('seacraft_enc3_short.csv');
      final parsed = service.parseFile(bytes);
      final id = await routeRepo.insertImportedRoute(
        points: parsed.points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: '005.DAT.csv',
      );
      final route = (await routeRepo.getById(id, includePoints: false))!;
      final weekLater = ParsedNavTrack(
        points: [
          for (final p in parsed.points)
            p.copyWith(
              timestamp: p.timestamp + const Duration(days: 7).inSeconds,
            ),
        ],
      );

      expect(NavTrackImportService.isSameRecording(route, parsed), isTrue);
      expect(NavTrackImportService.isSameRecording(route, weekLater), isFalse);
    });
  });
}
