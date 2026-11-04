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
