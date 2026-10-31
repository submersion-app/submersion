import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3918: a route linked to a dive that a consolidate or merge folds
/// away follows the dive, and an undo puts it back. Foreign keys stay on in
/// this file, as they are in the running app: the loss happens in the
/// `nav_tracks.dive_id` SET NULL action, which does nothing with them off.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late NavTrackRepository routes;
  late DiveConsolidationService consolidation;
  late DiveMergeService merge;

  final base = DateTime.utc(2026, 3, 1, 10);

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    diveRepo = DiveRepository();
    routes = NavTrackRepository();
    consolidation = DiveConsolidationService(diveRepo);
    merge = DiveMergeService(diveRepo);
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver1'),
            name: Value('diver1'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id, DateTime entry, {String? serial}) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 30),
        maxDepth: 18,
        diveComputerSerial: serial,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 900, depth: 18),
          domain.DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      ),
    );
  }

  /// Two recordings of one physical dive, from different computers.
  Future<void> seedOverlapping(List<String> ids) async {
    for (final (i, id) in ids.indexed) {
      await seedDive(id, base.add(Duration(minutes: i)), serial: 'SN-$id');
    }
  }

  /// Two halves of one dive, one after the other.
  Future<void> seedSequential(String first, String second) async {
    await seedDive(first, base);
    await seedDive(second, base.add(const Duration(minutes: 35)));
  }

  /// A route recorded [startAt] seconds into the epoch, linked to [diveId].
  Future<String> seedRoute(
    String diveId, {
    NavTrackLinkMode linkMode = NavTrackLinkMode.manual,
    int startAt = 1700000000,
  }) async {
    final id = await routes.insertImportedRoute(
      points: [
        for (var i = 0; i < 3; i++)
          NavTrackPoint(
            timestamp: startAt + i * 10,
            north: i * 10.0,
            east: 0,
            depth: 5,
            distance: i * 10.0,
            speed: 0.3,
          ),
      ],
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'route-$startAt.csv',
    );
    await routes.link(id, diveId, linkMode: linkMode);
    return id;
  }

  Future<NavTrackRow> routeRow(String id) =>
      (db.select(db.navTracks)..where((t) => t.id.equals(id))).getSingle();

  group('consolidation', () {
    test('a secondary route follows it onto the surviving dive', () async {
      await seedOverlapping(['a', 'b']);
      final route = await seedRoute('b');
      final before = await routeRow(route);

      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

      final after = await routeRow(route);
      expect(after.diveId, 'a');
      expect(after.linkMode, NavTrackLinkMode.manual.wireValue);
      expect(after.isPrimary, isTrue);
      expect(after.points, before.points);
      expect(await routes.getUnlinked(), isEmpty);
    });

    test('an auto-matched link stays auto', () async {
      await seedOverlapping(['a', 'b']);
      final route = await seedRoute('b', linkMode: NavTrackLinkMode.auto);

      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

      expect((await routeRow(route)).linkMode, NavTrackLinkMode.auto.wireValue);
    });

    test('marks the move for sync, so a peer does not unlink it', () async {
      await seedOverlapping(['a', 'b']);
      final route = await seedRoute('b');
      await db.delete(db.syncRecords).go();

      await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.recordId.equals(route))).get();
      expect(pending, hasLength(1));
      expect(pending.single.entityType, NavTrackRepository.entityType);
    });

    test(
      'keeps both links and the target primary when both have a route',
      () async {
        await seedOverlapping(['a', 'b']);
        final kept = await seedRoute('a', startAt: 1700000500);
        final moved = await seedRoute('b', startAt: 1700000000);

        await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

        final rows = await routes.getForDive('a');
        expect([for (final r in rows) r.id], [kept, moved]);
        expect(rows.first.isPrimary, isTrue);
        expect(rows.last.isPrimary, isFalse);
      },
    );

    test('leaves one primary when two secondaries each bring one', () async {
      await seedOverlapping(['a', 'b', 'c']);
      final later = await seedRoute('b', startAt: 1700000500);
      final earlier = await seedRoute('c', startAt: 1700000000);

      await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b', 'c'],
      );

      final rows = await routes.getForDive('a');
      expect([for (final r in rows) r.id], [earlier, later]);
      expect([for (final r in rows) r.isPrimary], [true, false]);
    });

    test('undo puts each route back on its own dive', () async {
      await seedOverlapping(['a', 'b']);
      final onTarget = await seedRoute('a', startAt: 1700000500);
      final onSecondary = await seedRoute(
        'b',
        linkMode: NavTrackLinkMode.auto,
        startAt: 1700000000,
      );

      final outcome = await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b'],
      );
      await consolidation.undo(outcome.snapshot);

      final target = await routeRow(onTarget);
      expect(target.diveId, 'a');
      expect(target.linkMode, NavTrackLinkMode.manual.wireValue);
      expect(target.isPrimary, isTrue);
      final secondary = await routeRow(onSecondary);
      expect(secondary.diveId, 'b');
      expect(secondary.linkMode, NavTrackLinkMode.auto.wireValue);
      expect(secondary.isPrimary, isTrue);
    });

    test(
      'undo keeps the target route of a dive with no secondary route',
      () async {
        await seedOverlapping(['a', 'b']);
        final route = await seedRoute('a');

        final outcome = await consolidation.apply(
          targetDiveId: 'a',
          secondaryDiveIds: ['b'],
        );
        await consolidation.undo(outcome.snapshot);

        expect((await routeRow(route)).diveId, 'a');
      },
    );

    test('undo keeps a route linked to the target after the fold', () async {
      await seedOverlapping(['a', 'b']);
      await seedRoute('b', startAt: 1700000000);

      final outcome = await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b'],
      );
      final linkedSince = await seedRoute('a', startAt: 1700000500);
      await consolidation.undo(outcome.snapshot);

      final row = await routeRow(linkedSince);
      expect(row.diveId, 'a');
      expect(row.linkMode, NavTrackLinkMode.manual.wireValue);
      // The fold's primary went home with the secondary, so this one is
      // the target's only route and has to draw.
      expect(row.isPrimary, isTrue);
    });

    test('undo keeps a position set since on a route that stayed', () async {
      await seedOverlapping(['a', 'b']);
      final stayed = await seedRoute('a');

      final outcome = await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b'],
      );
      await routes.setSite(stayed, null, anchor: const GeoPoint(1, 2));
      await consolidation.undo(outcome.snapshot);

      final row = await routeRow(stayed);
      expect(row.diveId, 'a');
      expect(row.anchorLatitude, 1);
      expect(row.anchorLongitude, 2);
    });

    test('undo keeps a position changed since on a route that moved', () async {
      await seedOverlapping(['a', 'b']);
      final moved = await seedRoute('b');
      await routes.setSite(moved, null, anchor: const GeoPoint(1, 2));

      final outcome = await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b'],
      );
      await routes.setSite(moved, null, anchor: const GeoPoint(3, 4));
      await consolidation.undo(outcome.snapshot);

      final row = await routeRow(moved);
      expect(row.diveId, 'b');
      expect(row.anchorLatitude, 3);
      expect(row.anchorLongitude, 4);
    });

    test('undo does not bring back a route deleted after the fold', () async {
      await seedOverlapping(['a', 'b']);
      final route = await seedRoute('b');

      final outcome = await consolidation.apply(
        targetDiveId: 'a',
        secondaryDiveIds: ['b'],
      );
      await routes.delete(route);
      await consolidation.undo(outcome.snapshot);

      expect(await routes.getById(route), isNull);
    });
  });

  group('merge', () {
    test('every source route moves to the merged dive', () async {
      await seedSequential('a', 'b');
      final first = await seedRoute('a', startAt: 1700000000);
      final second = await seedRoute(
        'b',
        linkMode: NavTrackLinkMode.auto,
        startAt: 1700000500,
      );

      final outcome = await merge.apply(['a', 'b']);

      final rows = await routes.getForDive(outcome.mergedDive.id);
      expect([for (final r in rows) r.id], [first, second]);
      expect([for (final r in rows) r.isPrimary], [true, false]);
      expect(
        [for (final r in rows) r.linkMode],
        [NavTrackLinkMode.manual, NavTrackLinkMode.auto],
      );
      expect(await routes.getUnlinked(), isEmpty);
    });

    test('undo puts each route back on its source dive', () async {
      await seedSequential('a', 'b');
      final first = await seedRoute('a', startAt: 1700000000);
      final second = await seedRoute(
        'b',
        linkMode: NavTrackLinkMode.auto,
        startAt: 1700000500,
      );

      final outcome = await merge.apply(['a', 'b']);
      await merge.undo(outcome.snapshot);

      final firstRow = await routeRow(first);
      expect(firstRow.diveId, 'a');
      expect(firstRow.linkMode, NavTrackLinkMode.manual.wireValue);
      expect(firstRow.isPrimary, isTrue);
      final secondRow = await routeRow(second);
      expect(secondRow.diveId, 'b');
      expect(secondRow.linkMode, NavTrackLinkMode.auto.wireValue);
      expect(secondRow.isPrimary, isTrue);
    });
  });
}
