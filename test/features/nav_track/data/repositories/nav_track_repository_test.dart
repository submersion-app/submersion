import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

import '../../../../helpers/test_database.dart';

List<NavTrackPoint> _samplePoints({int count = 5}) => [
  for (var i = 0; i < count; i++)
    NavTrackPoint(
      timestamp: 1700000000 + i * 10,
      north: i * 10.0,
      east: 0,
      depth: 5,
      distance: i * 10.0,
      speed: 0.3,
    ),
];

Future<void> _insertMinimalDive(AppDatabase db, String id) {
  return db.customStatement(
    "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
    "VALUES ('$id', 1700000000000, 1, 1)",
  );
}

Future<void> _insertSite(
  AppDatabase db,
  String id, {
  required double latitude,
  required double longitude,
}) {
  return db.customStatement(
    "INSERT INTO dive_sites (id, name, latitude, longitude, "
    "created_at, updated_at) "
    "VALUES ('$id', 'Test Site', $latitude, $longitude, 1, 1)",
  );
}

Future<void> _insertDiveWithSite(AppDatabase db, String id, String siteId) {
  return db.customStatement(
    "INSERT INTO dives (id, dive_date_time, site_id, created_at, updated_at) "
    "VALUES ('$id', 1700000000000, '$siteId', 1, 1)",
  );
}

Future<void> _insertDiveWithEntryLocation(
  AppDatabase db,
  String id, {
  required double latitude,
  required double longitude,
}) {
  return db.customStatement(
    "INSERT INTO dives (id, dive_date_time, entry_latitude, "
    "entry_longitude, created_at, updated_at) "
    "VALUES ('$id', 1700000000000, $latitude, $longitude, 1, 1)",
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

  group('insertImportedRoute', () {
    test('stores the route and its summary stats', () async {
      final points = _samplePoints();
      final id = await repo.insertImportedRoute(
        points: points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
      );

      final route = await repo.getById(id);
      expect(route, isNotNull);
      expect(route!.source, NavTrackSource.seacraftEnc);
      expect(route.sourceRef, '008.DAT.csv');
      expect(route.pointCount, points.length);
      expect(route.startTime, points.first.timestamp * 1000);
      expect(route.endTime, points.last.timestamp * 1000);
      expect(route.totalDistance, 40); // device distance, last sample
      expect(route.maxDepth, 5);
      expect(route.points, hasLength(points.length));
      expect(route.diveId, isNull);
      expect(route.linkMode, isNull);
      expect(route.isPrimary, isTrue);
    });

    test('rejects fewer than two samples', () async {
      expect(
        () => repo.insertImportedRoute(
          points: [_samplePoints(count: 1).single],
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'x.csv',
        ),
        throwsArgumentError,
      );
    });

    test('a route can be pre-linked to a dive at import time', () async {
      await _insertMinimalDive(db, 'd1');
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
        diveId: 'd1',
      );

      final route = await repo.getById(id);
      expect(route!.diveId, 'd1');
      expect(route.linkMode, NavTrackLinkMode.manual);
      expect(route.isPrimary, isTrue);
    });

    test('defaults the anchor to the chosen site\'s location (design spec '
        '"Georeferencing": the site pin is the default anchor)', () async {
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, latitude, longitude, "
        "created_at, updated_at) "
        "VALUES ('s1', 'Test Site', 47.1, 8.3, 1, 1)",
      );

      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
        siteId: 's1',
      );

      final route = await repo.getById(id);
      expect(route!.anchor, const GeoPoint(47.1, 8.3));
    });

    test('leaves the anchor null when no site is chosen', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
      );

      final route = await repo.getById(id);
      expect(route!.anchor, isNull);
    });

    test('does not hydrate points on a list read', () async {
      await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
      );
      final all = await repo.getAll();
      expect(all.single.points, isEmpty);
      expect(all.single.pointCount, 5);
    });

    test('stamps an hlc so the row is visible to sync', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
      );
      final row = await db
          .customSelect("SELECT hlc FROM nav_tracks WHERE id = '$id'")
          .getSingle();
      expect(row.read<String?>('hlc'), isNotNull);
    });
  });

  group('getUnlinked / getAll ordering', () {
    test('getUnlinked returns only routes with no dive link', () async {
      await _insertMinimalDive(db, 'd1');
      final linkedId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );
      final unlinkedId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'b.csv',
      );

      final unlinked = await repo.getUnlinked();
      expect(unlinked.map((r) => r.id), [unlinkedId]);
      expect(unlinked.map((r) => r.id), isNot(contains(linkedId)));
    });

    test('getAll lists unlinked routes before linked ones', () async {
      await _insertMinimalDive(db, 'd1');
      final linkedId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );
      final unlinkedId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'b.csv',
      );

      final all = await repo.getAll();
      expect(all.map((r) => r.id), [unlinkedId, linkedId]);
    });
  });

  group('link / unlink / setPrimary', () {
    test(
      'link sets diveId, linkMode and isPrimary on the first link',
      () async {
        await _insertMinimalDive(db, 'd1');
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
        );

        await repo.link(id, 'd1', linkMode: NavTrackLinkMode.auto);

        final route = await repo.getById(id);
        expect(route!.diveId, 'd1');
        expect(route.linkMode, NavTrackLinkMode.auto);
        expect(route.isPrimary, isTrue);
      },
    );

    test('a second route linked to the same dive is not primary', () async {
      await _insertMinimalDive(db, 'd1');
      final firstId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );
      final secondId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'b.csv',
      );

      await repo.link(secondId, 'd1', linkMode: NavTrackLinkMode.manual);

      final first = await repo.getById(firstId);
      final second = await repo.getById(secondId);
      expect(first!.isPrimary, isTrue);
      expect(second!.isPrimary, isFalse);
    });

    test('getForDive returns the primary route first', () async {
      await _insertMinimalDive(db, 'd1');
      final firstId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );
      final secondId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'b.csv',
        diveId: 'd1',
      );

      final routes = await repo.getForDive('d1');
      expect(routes.first.id, firstId);
      expect(routes.first.isPrimary, isTrue);
      expect(routes.last.id, secondId);
      expect(routes.last.isPrimary, isFalse);
    });

    test(
      'unlink clears diveId and linkMode without touching the recording',
      () async {
        await _insertMinimalDive(db, 'd1');
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
          diveId: 'd1',
        );

        await repo.unlink(id);

        final route = await repo.getById(id);
        expect(route!.diveId, isNull);
        expect(route.linkMode, isNull);
        expect(route.pointCount, 5);
      },
    );

    test(
      'unlinking then relinking to a fresh dive makes it primary again',
      () async {
        await _insertMinimalDive(db, 'd1');
        await _insertMinimalDive(db, 'd2');
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
          diveId: 'd1',
        );
        await repo.unlink(id);
        await repo.link(id, 'd2', linkMode: NavTrackLinkMode.manual);

        final route = await repo.getById(id);
        expect(route!.diveId, 'd2');
        expect(route.isPrimary, isTrue);
      },
    );

    test('setPrimary demotes the other route on the same dive', () async {
      await _insertMinimalDive(db, 'd1');
      final firstId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );
      final secondId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'b.csv',
      );
      await repo.link(secondId, 'd1', linkMode: NavTrackLinkMode.manual);

      await repo.setPrimary(secondId);

      final first = await repo.getById(firstId);
      final second = await repo.getById(secondId);
      expect(first!.isPrimary, isFalse);
      expect(second!.isPrimary, isTrue);
    });

    test('setPrimary stamps updatedAt and a pending sync record on every '
        'demoted sibling route too, not only the newly primary one '
        '(otherwise another device can retain a stale isPrimary: true and '
        'render a different route as primary)', () async {
      await _insertMinimalDive(db, 'd1');
      final firstId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );
      final secondId = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'b.csv',
      );
      await repo.link(secondId, 'd1', linkMode: NavTrackLinkMode.manual);

      await repo.setPrimary(secondId);

      final demoted = await repo.getById(firstId);
      final primary = await repo.getById(secondId);
      expect(demoted!.isPrimary, isFalse);
      expect(primary!.isPrimary, isTrue);
      // The demoted row must carry the same updatedAt as the new primary's,
      // not a stale one, so a peer applying both rows never sees the old
      // primary's flag survive a partial sync.
      expect(demoted.updatedAt, primary.updatedAt);

      final demotedPending = await db
          .customSelect(
            "SELECT local_updated_at FROM sync_records "
            "WHERE entity_type = 'navTracks' AND record_id = '$firstId'",
          )
          .getSingleOrNull();
      expect(demotedPending, isNotNull);
      expect(
        demotedPending!.read<int>('local_updated_at'),
        primary.updatedAt.millisecondsSinceEpoch,
      );
    });

    test('setPrimary throws for a route with no linked dive', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
      );
      expect(() => repo.setPrimary(id), throwsStateError);
    });

    group('link inherits the dive\'s existing site/location (item 5)', () {
      test(
        'linking a route with no site/anchor to a dive with a site '
        'inherits that site and its location as the route\'s anchor',
        () async {
          await _insertSite(db, 's1', latitude: 10.0, longitude: 20.0);
          await _insertDiveWithSite(db, 'd1', 's1');
          final id = await repo.insertImportedRoute(
            points: _samplePoints(),
            source: NavTrackSource.seacraftEnc,
            sourceRef: 'a.csv',
          );

          await repo.link(id, 'd1', linkMode: NavTrackLinkMode.manual);

          final route = await repo.getById(id);
          expect(route!.siteId, 's1');
          expect(route.anchorLatitude, 10.0);
          expect(route.anchorLongitude, 20.0);
        },
      );

      test('linking a route that already has its own site does NOT overwrite '
          'it with the dive\'s site', () async {
        await _insertSite(db, 's1', latitude: 10.0, longitude: 20.0);
        await _insertSite(db, 's2', latitude: 30.0, longitude: 40.0);
        await _insertDiveWithSite(db, 'd1', 's1');
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
          siteId: 's2',
        );

        await repo.link(id, 'd1', linkMode: NavTrackLinkMode.manual);

        final route = await repo.getById(id);
        expect(route!.siteId, 's2');
        expect(route.anchorLatitude, 30.0);
        expect(route.anchorLongitude, 40.0);
      });

      test('linking a route that already has its own anchor (no site) does '
          'NOT overwrite it, even though it has no siteId', () async {
        await _insertSite(db, 's1', latitude: 10.0, longitude: 20.0);
        await _insertDiveWithSite(db, 'd1', 's1');
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
        );
        await repo.updateCorrection(
          id,
          const NavTrackCorrection(
            anchor: GeoPoint(55.0, 66.0),
            endMode: NavTrackEndMode.none,
          ),
        );

        await repo.link(id, 'd1', linkMode: NavTrackLinkMode.manual);

        final route = await repo.getById(id);
        expect(route!.siteId, isNull);
        expect(route.anchorLatitude, 55.0);
        expect(route.anchorLongitude, 66.0);
      });

      test(
        'linking a route with no site/anchor to a dive with no site but '
        'with an entry location inherits the location only (no siteId)',
        () async {
          await _insertDiveWithEntryLocation(
            db,
            'd1',
            latitude: 12.0,
            longitude: 34.0,
          );
          final id = await repo.insertImportedRoute(
            points: _samplePoints(),
            source: NavTrackSource.seacraftEnc,
            sourceRef: 'a.csv',
          );

          await repo.link(id, 'd1', linkMode: NavTrackLinkMode.manual);

          final route = await repo.getById(id);
          expect(route!.siteId, isNull);
          expect(route.anchorLatitude, 12.0);
          expect(route.anchorLongitude, 34.0);
        },
      );

      test('linking to a dive with no site and no location leaves the '
          'route\'s site/anchor untouched (null stays null)', () async {
        await _insertMinimalDive(db, 'd1');
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
        );

        await repo.link(id, 'd1', linkMode: NavTrackLinkMode.manual);

        final route = await repo.getById(id);
        expect(route!.siteId, isNull);
        expect(route.anchorLatitude, isNull);
        expect(route.anchorLongitude, isNull);
      });
    });
  });

  group('updateCorrection', () {
    test(
      'writes and clears the anchor, end target and trust fraction',
      () async {
        final id = await repo.insertImportedRoute(
          points: _samplePoints(),
          source: NavTrackSource.seacraftEnc,
          sourceRef: 'a.csv',
        );

        await repo.updateCorrection(
          id,
          const NavTrackCorrection(
            anchor: GeoPoint(47.0, 8.0),
            endMode: NavTrackEndMode.sameAsStart,
            trustFraction: 0.5,
            headingOffsetDeg: 12,
          ),
        );
        var route = await repo.getById(id);
        expect(route!.anchor, const GeoPoint(47.0, 8.0));
        expect(route.endMode, NavTrackEndMode.sameAsStart);
        expect(route.trustFraction, 0.5);
        expect(route.headingOffsetDeg, 12);

        // Resetting the correction must actually clear the anchor, not
        // leave the previous value in place.
        await repo.updateCorrection(id, const NavTrackCorrection());
        route = await repo.getById(id);
        expect(route!.anchor, isNull);
        expect(route.endMode, NavTrackEndMode.none);
        expect(route.trustFraction, 0);
        expect(route.headingOffsetDeg, 0);
      },
    );

    test('point end mode round-trips the end coordinate', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
      );
      await repo.updateCorrection(
        id,
        const NavTrackCorrection(
          anchor: GeoPoint(47.0, 8.0),
          endMode: NavTrackEndMode.point,
          endPoint: GeoPoint(47.001, 8.001),
        ),
      );
      final route = await repo.getById(id);
      expect(route!.endMode, NavTrackEndMode.point);
      expect(route.endPoint, const GeoPoint(47.001, 8.001));
    });
  });

  group('rename', () {
    test('sets and clears the label', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
      );
      await repo.rename(id, 'My scooter dive');
      expect((await repo.getById(id))!.name, 'My scooter dive');
      await repo.rename(id, null);
      expect((await repo.getById(id))!.name, isNull);
    });
  });

  group('setSite', () {
    Future<void> insertSite(
      String id,
      double lat,
      double lon, {
      String name = 'Test Site',
    }) => db.customStatement(
      "INSERT INTO dive_sites (id, name, latitude, longitude, "
      "created_at, updated_at) "
      "VALUES ('$id', '$name', $lat, $lon, 1, 1)",
    );

    test('changes the siteId', () async {
      await insertSite('s1', 47.1, 8.3);
      await insertSite('s2', 47.2, 8.4);
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        siteId: 's1',
      );

      await repo.setSite(id, 's2');

      expect((await repo.getById(id))!.siteId, 's2');
    });

    test('writes the new anchor when the caller passes one (the anchor was '
        'untouched, so it follows the new site)', () async {
      await insertSite('s1', 47.1, 8.3);
      await insertSite('s2', 47.2, 8.4);
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        siteId: 's1',
      );
      expect((await repo.getById(id))!.anchor, const GeoPoint(47.1, 8.3));

      await repo.setSite(id, 's2', anchor: const GeoPoint(47.2, 8.4));

      final route = await repo.getById(id);
      expect(route!.siteId, 's2');
      expect(route.anchor, const GeoPoint(47.2, 8.4));
    });

    test('leaves the stored anchor untouched when the caller passes none (the '
        'diver had already moved the start point by hand)', () async {
      await insertSite('s1', 47.1, 8.3);
      await insertSite('s2', 47.2, 8.4);
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        siteId: 's1',
      );
      // The diver manually moved the start point away from the site pin.
      await repo.updateCorrection(
        id,
        const NavTrackCorrection(anchor: GeoPoint(50.0, 10.0)),
      );

      await repo.setSite(id, 's2');

      final route = await repo.getById(id);
      expect(route!.siteId, 's2');
      expect(route.anchor, const GeoPoint(50.0, 10.0));
    });
  });

  group('delete', () {
    test('removes the route and logs a tombstone', () async {
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
      );
      await repo.delete(id);
      expect(await repo.getById(id), isNull);

      final tombstones = await db
          .customSelect(
            "SELECT * FROM deletion_log WHERE entity_type = 'navTracks' "
            "AND record_id = '$id'",
          )
          .get();
      expect(tombstones, isNotEmpty);
    });

    test('deleting a dive leaves its routes unlinked, not deleted', () async {
      await _insertMinimalDive(db, 'd1');
      final id = await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
        diveId: 'd1',
      );

      await db.customStatement("DELETE FROM dives WHERE id = 'd1'");

      final route = await repo.getById(id);
      expect(route, isNotNull);
      expect(route!.diveId, isNull);
    });
  });

  group('watchChanges', () {
    test('emits after an insert', () async {
      final future = repo.watchChanges().first;
      await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'a.csv',
      );
      await expectLater(future, completes);
    });
  });
}
