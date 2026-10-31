import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertDive(
  AppDatabase db,
  String id, {
  String? diverId,
  String? siteId,
}) {
  final diver = diverId == null ? 'NULL' : "'$diverId'";
  final site = siteId == null ? 'NULL' : "'$siteId'";
  return db.customStatement(
    'INSERT INTO dives (id, diver_id, site_id, dive_date_time, created_at, '
    "updated_at) VALUES ('$id', $diver, $site, 1700000000000, 1, 1)",
  );
}

Future<void> _insertDiver(AppDatabase db, String id) {
  return db.customStatement(
    'INSERT INTO divers (id, name, created_at, updated_at) '
    "VALUES ('$id', '$id', 1, 1)",
  );
}

Future<void> _insertSite(AppDatabase db, String id) {
  return db.customStatement(
    'INSERT INTO dive_sites (id, name, latitude, longitude, created_at, '
    "updated_at) VALUES ('$id', 'Test Site', 10.5, 20.5, 1, 1)",
  );
}

void main() {
  late AppDatabase db;
  late NavTrackRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
    repo = NavTrackRepository();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<String> route({
    required int startAt,
    String? diveId,
    NavTrackLinkMode linkMode = NavTrackLinkMode.manual,
  }) async {
    final id = await repo.insertImportedRoute(
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
    if (diveId != null) await repo.link(id, diveId, linkMode: linkMode);
    return id;
  }

  group('linkedRowsForDives', () {
    test('leaves the points out and skips other dives', () async {
      await _insertDive(db, 'a');
      await _insertDive(db, 'other');
      final onA = await route(startAt: 1700000000, diveId: 'a');
      await route(startAt: 1700000100, diveId: 'other');
      await route(startAt: 1700000200);

      final rows = await repo.linkedRowsForDives(['a']);

      expect([for (final r in rows) r.id], [onA]);
      expect(rows.single.points, isEmpty);
    });

    test('orders primary first, then by recording, across dives', () async {
      await _insertDive(db, 'a');
      await _insertDive(db, 'b');
      final aPrimary = await route(startAt: 1700000500, diveId: 'a');
      final aSecond = await route(startAt: 1700000000, diveId: 'a');
      final bPrimary = await route(startAt: 1700000100, diveId: 'b');

      final rows = await repo.linkedRowsForDives(['a', 'b']);

      expect([for (final r in rows) r.id], [bPrimary, aPrimary, aSecond]);
    });

    test('returns nothing for no dives', () async {
      expect(await repo.linkedRowsForDives(const []), isEmpty);
    });
  });

  group('moveLinks', () {
    test('moves the owner to the receiving dive\'s diver', () async {
      await _insertDiver(db, 'diver-a');
      await _insertDiver(db, 'diver-b');
      await _insertDive(db, 'a', diverId: 'diver-a');
      await _insertDive(db, 'b', diverId: 'diver-b');
      final id = await route(startAt: 1700000000, diveId: 'b');

      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');

      final row = (await repo.linkedRowsForDives(['a'])).single;
      expect(row.id, id);
      expect(row.diverId, 'diver-a');
    });

    test('gives a route with no position the receiving dive\'s site', () async {
      await _insertSite(db, 'site-1');
      await _insertDive(db, 'a', siteId: 'site-1');
      await _insertDive(db, 'b');
      await route(startAt: 1700000000, diveId: 'b');

      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');

      final moved = (await repo.getForDive('a')).single;
      expect(moved.siteId, 'site-1');
      expect(moved.anchor?.latitude, 10.5);
    });

    test('a non-primary route stays behind the one it came with', () async {
      await _insertDive(db, 'a');
      await _insertDive(db, 'b');
      final primary = await route(startAt: 1700000500, diveId: 'b');
      final second = await route(startAt: 1700000000, diveId: 'b');

      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');

      final rows = await repo.getForDive('a');
      expect([for (final r in rows) r.id], [primary, second]);
      expect([for (final r in rows) r.isPrimary], [true, false]);
      expect(await repo.routeIdsLinkedToDive('b'), isEmpty);
    });

    test('does nothing for a dive with no routes', () async {
      await _insertDive(db, 'a');
      await _insertDive(db, 'b');
      final own = await route(startAt: 1700000000, diveId: 'a');

      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');

      expect(await repo.routeIdsLinkedToDive('a'), [own]);
    });
  });

  group('restoreLinks', () {
    test('restores the link columns and nothing else', () async {
      await _insertSite(db, 'site-1');
      await _insertDive(db, 'a', siteId: 'site-1');
      await _insertDive(db, 'b');
      final id = await route(
        startAt: 1700000000,
        diveId: 'b',
        linkMode: NavTrackLinkMode.auto,
      );
      final captured = await repo.linkedRowsForDives(['b']);
      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');
      await repo.rename(id, 'Reef loop');

      await repo.restoreLinks(captured);

      final restored = (await repo.getForDive('b')).single;
      expect(restored.linkMode, NavTrackLinkMode.auto);
      expect(restored.siteId, isNull);
      expect(restored.anchor, isNull);
      expect(restored.name, 'Reef loop');
      expect((await repo.getById(id))!.points, hasLength(3));
    });

    test('a site and anchor changed since stand', () async {
      await _insertSite(db, 'site-1');
      await _insertSite(db, 'site-2');
      await _insertDive(db, 'a');
      await _insertDive(db, 'b');
      final id = await route(startAt: 1700000000, diveId: 'b');
      await repo.setSite(id, 'site-1', anchor: const GeoPoint(1, 2));
      final captured = await repo.linkedRowsForDives(['b']);
      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');
      await repo.setSite(id, 'site-2', anchor: const GeoPoint(3, 4));

      await repo.restoreLinks(captured);

      final restored = (await repo.getForDive('b')).single;
      expect(restored.siteId, 'site-2');
      expect(restored.anchor, const GeoPoint(3, 4));
    });

    test('an anchor cleared since stays cleared', () async {
      await _insertDive(db, 'a');
      await _insertDive(db, 'b');
      final id = await route(startAt: 1700000000, diveId: 'b');
      await repo.setSite(id, null, anchor: const GeoPoint(1, 2));
      final captured = await repo.linkedRowsForDives(['b']);
      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');
      await repo.setSite(id, null, clearAnchor: true);

      await repo.restoreLinks(captured);

      expect((await repo.getForDive('b')).single.anchor, isNull);
    });

    test('a site deleted since does not stop the restore', () async {
      await _insertSite(db, 'site-1');
      await _insertDive(db, 'a');
      await _insertDive(db, 'b');
      final id = await route(startAt: 1700000000, diveId: 'b');
      await repo.setSite(id, 'site-1');
      final captured = await repo.linkedRowsForDives(['b']);
      await repo.moveLinks(fromDiveIds: ['b'], toDiveId: 'a');
      await db.customStatement("DELETE FROM dive_sites WHERE id = 'site-1'");

      await repo.restoreLinks(captured);

      final restored = (await repo.getForDive('b')).single;
      expect(restored.id, id);
      expect(restored.siteId, isNull);
    });

    test('marks each restored route pending', () async {
      await _insertDive(db, 'a');
      final id = await route(startAt: 1700000000, diveId: 'a');
      final captured = await repo.linkedRowsForDives(['a']);
      await db.delete(db.syncRecords).go();

      await repo.restoreLinks(captured);

      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.recordId.equals(id))).get();
      expect(pending, hasLength(1));
    });

    test('leaves no record for a route deleted since', () async {
      await _insertDive(db, 'a');
      final id = await route(startAt: 1700000000, diveId: 'a');
      final captured = await repo.linkedRowsForDives(['a']);
      await repo.delete(id);
      await db.delete(db.syncRecords).go();

      await repo.restoreLinks(captured);

      expect(await repo.getById(id), isNull);
      expect(await db.select(db.syncRecords).get(), isEmpty);
    });

    test(
      'promotes a remaining route when a dive is left with no primary',
      () async {
        await _insertDive(db, 'a');
        await _insertDive(db, 'b');
        final primary = await route(startAt: 1700000000, diveId: 'a');
        final other = await route(startAt: 1700000500, diveId: 'a');
        final captured = (await repo.linkedRowsForDives([
          'a',
        ])).where((r) => r.id == other);
        await repo.unlink(primary);
        await repo.link(primary, 'b', linkMode: NavTrackLinkMode.manual);
        await db.customStatement(
          "UPDATE nav_tracks SET is_primary = 0 WHERE id = '$other'",
        );

        await repo.restoreLinks(captured.toList());

        expect((await repo.getById(other))!.isPrimary, isTrue);
      },
    );
  });
}
