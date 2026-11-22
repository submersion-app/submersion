import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Surface GPS tracks and underwater routes, as the GPS log and the route
/// pages keep them.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;

  /// 2024-03-14 09:00 to 09:10 wall clock, a fix a minute.
  const start = 1710406800000;

  Future<String> gps() => GpsTrackRepository().insertImportedTrack(
    points: [
      for (var i = 0; i <= 10; i++)
        GpsTrackPoint(
          timestamp: start ~/ 1000 + i * 60,
          latitude: 27 + i / 1000,
          longitude: 33,
        ),
    ],
    startTimeMs: start,
    endTimeMs: start + 600000,
    tzOffsetMinutes: 0,
    source: 'gpx',
    name: 'Boat',
  );

  Future<void> route(String id, {String? dive, bool primary = true}) => db
      .into(db.navTracks)
      .insert(
        NavTracksCompanion.insert(
          id: id,
          source: 'suunto_route',
          startTime: start,
          endTime: start + 600000,
          pointCount: 0,
          points: Uint8List(0),
          diveId: Value(dive),
          diverId: const Value(kDiverA),
          isPrimary: Value(primary),
          createdAt: kSeedTime,
          updatedAt: kSeedTime,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('a GPS track is trimmed, split and deleted', () async {
    final id = await gps();

    await h.run([
      updateOp('gps_tracks', id, {
        'trim_start_time': '2024-03-14T09:01:00Z',
        'trim_end_time': '2024-03-14T09:09:00Z',
      }),
    ]);
    final trimmed = (await h.one('gps_tracks', id))!;
    expect(trimmed['trim_start_time'], '2024-03-14T09:01:00.000Z');

    final split = await h.preview([
      updateOp('gps_tracks', id, {'split_at': '2024-03-14T09:05:00Z'}),
    ]);
    expect(split.items.single.alsoCreates, {'gps_tracks': 2});
    await h.apply(split);
    expect(await h.one('gps_tracks', id), isNull);
    final halves = await db.select(db.gpsTracks).get();
    expect([for (final t in halves) t.name]..sort(), ['Boat (1)', 'Boat (2)']);

    await h.run([deleteOp('gps_tracks', halves.first.id)]);
    expect(await db.select(db.gpsTracks).get(), hasLength(1));
  });

  test('a trim outside the track is refused', () async {
    final id = await gps();

    final plan = await h.preview([
      updateOp('gps_tracks', id, {'trim_start_time': '2024-03-14T08:00:00Z'}),
    ]);
    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
    final backwards = await h.preview([
      updateOp('gps_tracks', id, {
        'trim_start_time': '2024-03-14T09:08:00Z',
        'trim_end_time': '2024-03-14T09:02:00Z',
      }),
    ]);
    expect(backwards.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a route is linked, made primary, corrected and unlinked', () async {
    await route('r1');
    await route('r2', dive: 'd1');

    final link = await h.preview([
      updateOp('nav_tracks', 'r1', {'dive_id': 'd1', 'name': '  '}),
    ]);
    // The dive has a primary route, so this one joins it as a second.
    final primary = link.items.single.fields['is_primary']!;
    expect([primary.newValue, primary.indirect], [false, true]);
    await h.apply(link);
    final linked = (await h.one('nav_tracks', 'r1'))!;
    expect(
      [linked['dive_id'], linked['is_primary'], linked['name']],
      ['d1', false, null],
    );

    final star = await h.preview([
      updateOp('nav_tracks', 'r1', {'is_primary': true}),
    ]);
    expect(star.items.single.alsoChanges, {'nav_tracks': 1});
    await h.apply(star);
    expect((await h.one('nav_tracks', 'r2'))!['is_primary'], isFalse);

    await h.run([
      updateOp('nav_tracks', 'r1', {
        'scale_factor': 1.5,
        'heading_offset_deg': -10,
      }),
    ]);
    expect((await h.one('nav_tracks', 'r1'))!['scale_factor'], 1.5);

    await h.run([
      updateOp('nav_tracks', 'r1', {'dive_id': null}),
    ]);
    expect((await h.one('nav_tracks', 'r1'))!['dive_id'], isNull);
    expect((await h.one('nav_tracks', 'r2'))!['is_primary'], isTrue);
  });

  group('a site change moves the anchor as the track page does', () {
    Future<void> sites() => db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, latitude, longitude, '
      "created_at, updated_at) VALUES ('sa', '$kDiverA', 'A', 10.0, 20.0, "
      "1, 1), ('sb', '$kDiverA', 'B', 30.0, 40.0, 1, 1)",
    );

    Future<void> placeOnSiteA(double lat, double lon) =>
        (db.update(db.navTracks)..where((t) => t.id.equals('r1'))).write(
          NavTracksCompanion(
            siteId: const Value('sa'),
            anchorLatitude: Value(lat),
            anchorLongitude: Value(lon),
          ),
        );

    Future<List<Object?>> place() async {
      final row = (await h.one('nav_tracks', 'r1'))!;
      return [row['site_id'], row['anchor_latitude'], row['anchor_longitude']];
    }

    test('an anchor on the old site\'s pin moves to the new one', () async {
      await sites();
      await route('r1');
      await placeOnSiteA(10.0, 20.0);

      await h.run([
        updateOp('nav_tracks', 'r1', {'site_id': 'sb'}),
      ]);

      expect(await place(), ['sb', 30.0, 40.0]);
    });

    test(
      'a correction change in the same update keeps the moved anchor',
      () async {
        await sites();
        await route('r1');
        await placeOnSiteA(10.0, 20.0);

        await h.run([
          updateOp('nav_tracks', 'r1', {'site_id': 'sb', 'scale_factor': 1.2}),
        ]);

        expect(await place(), ['sb', 30.0, 40.0]);
        expect((await h.one('nav_tracks', 'r1'))!['scale_factor'], 1.2);
      },
    );

    // The preview names the site a dive change brings, as apply writes it.
    Future<void> divesAtSites() => db.customStatement(
      'INSERT INTO dives (id, diver_id, site_id, dive_date_time, created_at, '
      "updated_at) VALUES ('da', '$kDiverA', 'sa', $start, 1, 1), "
      "('db', '$kDiverA', 'sb', $start, 1, 1)",
    );

    test('the preview shows an anchored route with no site taking the '
        'dive\'s', () async {
      await sites();
      await divesAtSites();
      await route('r1');
      await (db.update(db.navTracks)..where((t) => t.id.equals('r1'))).write(
        const NavTracksCompanion(
          anchorLatitude: Value(1.0),
          anchorLongitude: Value(2.0),
        ),
      );

      final preview = await h.preview([
        updateOp('nav_tracks', 'r1', {'dive_id': 'db'}),
      ]);

      final site = preview.items.single.fields['site_id']!;
      expect([site.newValue, site.indirect], ['sb', true]);
      await h.apply(preview);
      expect((await place())[0], 'sb');
    });

    test('the preview shows a site taken from the old dive moving to the '
        'new dive\'s', () async {
      await sites();
      await divesAtSites();
      await route('r1', dive: 'da');
      await placeOnSiteA(10.0, 20.0);

      final preview = await h.preview([
        updateOp('nav_tracks', 'r1', {'dive_id': 'db'}),
      ]);

      final site = preview.items.single.fields['site_id']!;
      expect([site.newValue, site.indirect], ['sb', true]);
      await h.apply(preview);
      expect(await place(), ['sb', 30.0, 40.0]);
    });

    test('an anchor placed by hand stays', () async {
      await sites();
      await route('r1');
      await placeOnSiteA(1.0, 2.0);

      await h.run([
        updateOp('nav_tracks', 'r1', {'site_id': 'sb'}),
      ]);

      expect(await place(), ['sb', 1.0, 2.0]);
    });
  });

  test('a scale of 5 is refused', () async {
    await route('r1');

    final plan = await h.preview([
      updateOp('nav_tracks', 'r1', {'scale_factor': 5}),
      updateOp('nav_tracks', 'r1', {'is_primary': true}),
    ]);

    expect(plan.items.first.block, isNotNull);
  });

  test('deleting a primary route promotes its sibling, listed', () async {
    await route('r1', dive: 'd1');
    await route('r2', dive: 'd1', primary: false);

    final plan = await h.preview([deleteOp('nav_tracks', 'r1')]);
    expect(plan.items.single.alsoChanges, {'nav_tracks': 1});
    await h.apply(plan);

    expect((await h.one('nav_tracks', 'r2'))!['is_primary'], isTrue);
  });

  // setPrimary demotes the destination dive's primary, so a move made
  // primary lists that route as changed, not only the old dive's.
  test('a route moved and made primary lists the primary it demotes', () async {
    await h.dive('d3');
    await route('r1', dive: 'd3', primary: false);
    await route('r2', dive: 'd1');

    final plan = await h.preview([
      updateOp('nav_tracks', 'r1', {'dive_id': 'd1', 'is_primary': true}),
    ]);
    expect(plan.items.single.alsoChanges, {'nav_tracks': 1});
    await h.apply(plan);

    expect((await h.one('nav_tracks', 'r1'))!['is_primary'], isTrue);
    expect((await h.one('nav_tracks', 'r2'))!['is_primary'], isFalse);
  });
}
