import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_route.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_route_writer.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../../helpers/test_database.dart';

SuuntoParsedDive _parsed({SuuntoDiveRoute? route, String? serial = 'NS-1'}) =>
    SuuntoParsedDive(
      dive: DownloadedDive(
        startTime: DateTime.utc(2026, 4, 19, 13, 44, 40),
        durationSeconds: 1800,
        maxDepth: 12,
        profile: const [],
      ),
      deviceName: 'Suunto Nautic S',
      serialNumber: serial,
      route: route,
    );

SuuntoDiveRoute _route({double? lat = 47.3, double? lon = -2.9}) =>
    SuuntoDiveRoute(
      points: const [
        NavTrackPoint(timestamp: 1776606280, north: 0, east: 0, depth: 1),
        NavTrackPoint(timestamp: 1776606281, north: 1, east: 1, depth: 2),
      ],
      originLatitude: lat,
      originLongitude: lon,
    );

Future<void> _insertDive(
  AppDatabase db,
  String id, {
  double? lat,
  double? lon,
}) => db.customStatement(
  'INSERT INTO dives (id, dive_date_time, entry_latitude, '
  'entry_longitude, created_at, updated_at) '
  "VALUES ('$id', 1700000000000, ${lat ?? 'NULL'}, ${lon ?? 'NULL'}, 1, 1)",
);

void main() {
  late AppDatabase db;
  late NavTrackRepository repo;
  late SuuntoRouteWriter writer;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
    repo = NavTrackRepository();
    writer = SuuntoRouteWriter(repository: repo);
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('sourceRef is the device serial plus the dive start', () {
    expect(
      SuuntoRouteWriter.sourceRefFor(_parsed()),
      'suunto:NS-1:2026-04-19T13:44:40.000Z',
    );
    expect(
      SuuntoRouteWriter.sourceRefFor(_parsed(serial: null)),
      'suunto:Suunto Nautic S:2026-04-19T13:44:40.000Z',
    );
  });

  test('does nothing for a dive without a route', () async {
    await _insertDive(db, 'd1');
    expect(await writer.attach('d1', _parsed()), isNull);
    expect(await repo.getForDive('d1'), isEmpty);
  });

  test('inserts a primary Suunto route anchored at DiveRouteOrigin', () async {
    await _insertDive(db, 'd1', lat: 10, lon: 20);
    final id = await writer.attach('d1', _parsed(route: _route()));

    final stored = (await repo.getForDive('d1')).single;
    expect(stored.id, id);
    expect(stored.source, NavTrackSource.suuntoRoute);
    expect(stored.isPrimary, isTrue);
    expect(stored.deviceName, 'Suunto Nautic S');
    expect(stored.anchor, const GeoPoint(47.3, -2.9));
  });

  test(
    'falls back to the dive entry fix when the export had no origin',
    () async {
      await _insertDive(db, 'd1', lat: 10, lon: 20);
      await writer.attach('d1', _parsed(route: _route(lat: null, lon: null)));

      expect(
        (await repo.getForDive('d1')).single.anchor,
        const GeoPoint(10, 20),
      );
    },
  );

  test(
    'a re-import replaces the same Suunto route, keeping one primary',
    () async {
      await _insertDive(db, 'd1');
      final first = await writer.attach('d1', _parsed(route: _route()));
      final second = await writer.attach('d1', _parsed(route: _route()));

      final routes = await repo.getForDive('d1');
      expect(routes.map((r) => r.id), [second]);
      expect(routes.single.isPrimary, isTrue);
      expect(second, isNot(first));
    },
  );

  test('another source keeps primary; the Suunto route is secondary', () async {
    await _insertDive(db, 'd1');
    final seacraft = await repo.insertImportedRoute(
      points: _route().points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: '008.DAT.csv',
      diveId: 'd1',
    );
    final suunto = await writer.attach('d1', _parsed(route: _route()));

    final routes = {for (final r in await repo.getForDive('d1')) r.id: r};
    expect(routes[seacraft]!.isPrimary, isTrue);
    expect(routes[suunto]!.isPrimary, isFalse);
  });

  test('a failed write is logged and returns null, never throws', () async {
    // No dive row: the foreign key rejects the insert.
    expect(await writer.attach('missing', _parsed(route: _route())), isNull);
  });

  // A dive imported before routes existed gets its route when the diver
  // re-imports it and picks Skip (#1445): the dive is left alone, but a
  // missing route is filled in.
  group('attachIfMissing', () {
    test('links the route when the dive has no Suunto route', () async {
      await _insertDive(db, 'd1');
      final id = await writer.attachIfMissing('d1', _parsed(route: _route()));

      expect(id, isNotNull);
      expect((await repo.getForDive('d1')).single.id, id);
    });

    test('leaves a dive that already has a Suunto route alone', () async {
      await _insertDive(db, 'd1');
      final first = await writer.attach(
        'd1',
        _parsed(route: _route(), serial: 'OTHER'),
      );

      expect(
        await writer.attachIfMissing('d1', _parsed(route: _route())),
        isNull,
      );
      expect((await repo.getForDive('d1')).map((r) => r.id), [first]);
    });

    test('is not blocked by a route from another source', () async {
      await _insertDive(db, 'd1');
      await repo.insertImportedRoute(
        points: _route().points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
        diveId: 'd1',
      );

      expect(
        await writer.attachIfMissing('d1', _parsed(route: _route())),
        isNotNull,
      );
      expect(await repo.getForDive('d1'), hasLength(2));
    });

    test('does nothing for a dive without a route', () async {
      await _insertDive(db, 'd1');
      expect(await writer.attachIfMissing('d1', _parsed()), isNull);
    });

    test('a failed lookup is logged and returns null', () async {
      expect(
        await writer.attachIfMissing('missing', _parsed(route: _route())),
        isNull,
      );
    });
  });
}
