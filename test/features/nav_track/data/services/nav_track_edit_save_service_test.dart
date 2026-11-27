import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_edit_save_service.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// An underwater track page's sitting is written as one History entry,
/// writes only what it changed, and moves the dive link through the
/// repository's own rules (issue #4527, phase 3, plan 5).
void main() {
  late AppDatabase db;
  late NavTrackRepository routes;
  late NavTrackEditSaveService service;
  late String r1;
  late String r2;
  late String r3;
  final changeLog = ChangeLogRepository();

  const s1Pin = GeoPoint(28.5, 34.5);
  const s2Pin = GeoPoint(27.9, 34.3);
  const s3Pin = GeoPoint(29.1, 34.7);

  final points = [
    for (var i = 0; i < 5; i++)
      NavTrackPoint(
        timestamp: 1700000000 + i * 10,
        north: i * 10.0,
        east: 0,
        depth: 5,
        distance: i * 10.0,
        speed: 0.3,
      ),
  ];

  Future<NavTrack> route(String id) async =>
      (await routes.getById(id, includePoints: false))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({NavTrack before, NavTrack after})?> save(
    String id,
    EditSession<NavTrack> session,
  ) => service.save(
    routeId: id,
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    routes = NavTrackRepository();
    service = NavTrackEditSaveService(routes);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 1, 1)",
    );
    for (final (id, pin) in [('s1', s1Pin), ('s2', s2Pin), ('s3', s3Pin)]) {
      await db.customStatement(
        'INSERT INTO dive_sites (id, name, latitude, longitude, created_at, '
        "updated_at) VALUES ('$id', '$id', ${pin.latitude}, "
        '${pin.longitude}, 1, 1)',
      );
    }
    for (final (id, site) in [('d1', 's1'), ('d2', 's2'), ('d3', 's3')]) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, site_id, '
        "created_at, updated_at) VALUES ('$id', 'me', 1700000000000, "
        "'$site', 1, 1)",
      );
    }
    r1 = await routes.insertImportedRoute(
      points: points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'r1.csv',
      name: 'Morning',
      diveId: 'd1',
      siteId: 's1',
      anchorLatitude: s1Pin.latitude,
      anchorLongitude: s1Pin.longitude,
    );
    r2 = await routes.insertImportedRoute(
      points: points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'r2.csv',
      diveId: 'd1',
    );
    r3 = await routes.insertImportedRoute(
      points: points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'r3.csv',
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('the routes start as the tests expect', () async {
    expect((await route(r1)).isPrimary, isTrue);
    expect((await route(r2)).isPrimary, isFalse);
    expect((await route(r3)).diveId, isNull);
  });

  test('a rename is one History entry', () async {
    final session = EditSession(await route(r1))
      ..set(navTrackNameField, 'Evening');

    final result = await save(r1, session);

    expect((await route(r1)).name, 'Evening');
    expect(result!.before.name, 'Morning');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:nav_tracks:$r1:header');
  });

  /// Each column the sitting writes, changed underneath while the sitting
  /// changes a different card: the change underneath survives the save.
  final census = <String, ({String sql, bool Function(NavTrack) kept})>{
    'name': (
      sql: "UPDATE nav_tracks SET name = 'Renamed'",
      kept: (t) => t.name == 'Renamed',
    ),
    'site': (
      sql: "UPDATE nav_tracks SET site_id = 's2'",
      kept: (t) => t.siteId == 's2',
    ),
    'device': (
      sql: "UPDATE nav_tracks SET equipment_id = NULL, device_name = 'Box'",
      kept: (t) => t.deviceName == 'Box',
    ),
    'anchor': (
      sql: 'UPDATE nav_tracks SET anchor_latitude = 1, anchor_longitude = 2',
      kept: (t) => t.anchor == const GeoPoint(1, 2),
    ),
    'end': (
      sql:
          "UPDATE nav_tracks SET end_mode = 'point', end_latitude = 3, "
          'end_longitude = 4',
      kept: (t) =>
          t.endMode == NavTrackEndMode.point &&
          t.endPoint == const GeoPoint(3, 4),
    ),
    'trust': (
      sql: 'UPDATE nav_tracks SET trust_fraction = 0.5',
      kept: (t) => t.trustFraction == 0.5,
    ),
    'heading': (
      sql: 'UPDATE nav_tracks SET heading_offset_deg = 12',
      kept: (t) => t.headingOffsetDeg == 12,
    ),
    'scale': (
      sql: 'UPDATE nav_tracks SET scale_factor = 1.5',
      kept: (t) => t.scaleFactor == 1.5,
    ),
    'dive': (
      sql: "UPDATE nav_tracks SET dive_id = 'd2'",
      kept: (t) => t.diveId == 'd2',
    ),
  };

  for (final MapEntry(key: column, value: change) in census.entries) {
    test('census: $column changed underneath survives a save', () async {
      final session = EditSession(await route(r1));
      // Change a card other than the one the column belongs to.
      if (column == 'name') {
        session.set(navTrackDeviceField, (equipmentId: null, deviceName: 'X'));
      } else {
        session.set(navTrackNameField, 'Evening');
      }
      await db.customStatement("${change.sql} WHERE id = '$r1'");

      await save(r1, session);

      expect(change.kept(await route(r1)), isTrue, reason: column);
    });
  }

  test('unlinking promotes the sibling in the same entry', () async {
    final session = EditSession(await route(r1))..set(navTrackDiveField, null);

    await save(r1, session);

    final unlinked = await route(r1);
    expect(unlinked.diveId, isNull);
    expect(unlinked.linkMode, isNull);
    expect((await route(r2)).isPrimary, isTrue);
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:nav_tracks:$r1:dive');
  });

  test('relinking moves the route to the new dive', () async {
    final session = EditSession(await route(r1))..set(navTrackDiveField, 'd2');

    await save(r1, session);

    final moved = await route(r1);
    expect(moved.diveId, 'd2');
    expect(moved.linkMode, NavTrackLinkMode.manual);
    expect(moved.isPrimary, isTrue);
    expect((await route(r2)).isPrimary, isTrue);
    expect(await operations(), hasLength(1));
  });

  test("changing the dive brings the new dive's site, and the anchor that "
      "sat on the old site's pin (#4851)", () async {
    final session = EditSession(await route(r1))..set(navTrackDiveField, 'd2');

    await save(r1, session);

    final moved = await route(r1);
    expect(moved.diveId, 'd2');
    expect(moved.siteId, 's2');
    expect(moved.anchor, s2Pin);
  });

  test(
    "a dive another device moved meanwhile goes to the diver's choice",
    () async {
      final session = EditSession(await route(r1))
        ..set(navTrackDiveField, 'd3');
      await db.customStatement(
        "UPDATE nav_tracks SET dive_id = 'd2' WHERE id = '$r1'",
      );

      await save(r1, session);

      expect((await route(r1)).diveId, 'd3');
    },
  );

  test(
    'a site picked and a dive linked together keep the picked site',
    () async {
      final session = EditSession(await route(r3))
        ..set(navTrackSiteField, 's2')
        ..set(navTrackAnchorField, s2Pin)
        ..set(navTrackDiveField, 'd3');

      await save(r3, session);

      final linked = await route(r3);
      expect(linked.diveId, 'd3');
      expect(linked.siteId, 's2');
      expect(linked.anchor, s2Pin);
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(
        ops.single['label'],
        'record_edit:nav_tracks:$r3:correction,dive,site',
      );
    },
  );

  test(
    "linking a route with no site inherits the dive's site and anchor",
    () async {
      final session = EditSession(await route(r3))
        ..set(navTrackDiveField, 'd3');

      await save(r3, session);

      final linked = await route(r3);
      expect(linked.diveId, 'd3');
      expect(linked.siteId, 's3');
      expect(linked.anchor, s3Pin);
      // The route belongs to whoever logged the dive.
      final owner = await db
          .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$r3'")
          .getSingle();
      expect(owner.read<String?>('diver_id'), 'me');
    },
  );

  test('the correction is written whole from its two fields', () async {
    final session = EditSession(await route(r1));
    setNavTrackCorrection(
      session,
      const NavTrackCorrection(
        anchor: GeoPoint(10, 20),
        endMode: NavTrackEndMode.sameAsStart,
        trustFraction: 0.25,
        headingOffsetDeg: 5,
        scaleFactor: 1.1,
      ),
    );

    await save(r1, session);

    final corrected = await route(r1);
    expect(corrected.anchor, const GeoPoint(10, 20));
    expect(corrected.endMode, NavTrackEndMode.sameAsStart);
    expect(corrected.trustFraction, 0.25);
    expect(corrected.headingOffsetDeg, 5);
    expect(corrected.scaleFactor, 1.1);
  });

  test('unchanged returns null', () async {
    final session = EditSession(await route(r1))
      ..set(navTrackNameField, 'Evening');
    await db.customStatement(
      "UPDATE nav_tracks SET name = 'Evening' WHERE id = '$r1'",
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');

    expect(await save(r1, session), isNull);
    expect(await operations(), isEmpty);
  });

  test('a deleted route throws', () async {
    final session = EditSession(await route(r1))
      ..set(navTrackNameField, 'Evening');
    await routes.delete(r1);

    await expectLater(save(r1, session), throwsStateError);
  });

  test(
    'a dive deleted meanwhile is not linked, and the rest is saved',
    () async {
      final session = EditSession(await route(r1))
        ..set(navTrackDiveField, 'd3')
        ..set(navTrackNameField, 'Evening');
      await db.customStatement("DELETE FROM dives WHERE id = 'd3'");

      await save(r1, session);

      final saved = await route(r1);
      expect(saved.name, 'Evening');
      expect(saved.diveId, 'd1');
      expect((await route(r2)).isPrimary, isFalse);
    },
  );

  test('a site deleted meanwhile is not set, and the rest is saved', () async {
    final session = EditSession(await route(r1))
      ..set(navTrackSiteField, 's2')
      ..set(navTrackNameField, 'Evening');
    await db.customStatement(
      "UPDATE dives SET site_id = NULL WHERE site_id = 's2'",
    );
    await db.customStatement("DELETE FROM dive_sites WHERE id = 's2'");

    await save(r1, session);

    final saved = await route(r1);
    expect(saved.name, 'Evening');
    expect(saved.siteId, 's1');
  });

  test(
    'a site deleted meanwhile takes back the anchor its pick moved',
    () async {
      final session = EditSession(await route(r1));
      pickNavTrackSite(
        session,
        const DiveSite(id: 's2', name: 's2', location: s2Pin),
        oldSiteLocation: s1Pin,
      );
      session.set(navTrackNameField, 'Evening');
      await db.customStatement(
        "UPDATE dives SET site_id = NULL WHERE site_id = 's2'",
      );
      await db.customStatement("DELETE FROM dive_sites WHERE id = 's2'");

      await service.save(
        routeId: r1,
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        anchorFromSite: navTrackAnchorFromSite(session),
      );

      final saved = await route(r1);
      expect(saved.name, 'Evening');
      expect(saved.siteId, 's1');
      expect(saved.anchor, s1Pin);
    },
  );

  test('a site deleted meanwhile keeps an anchor placed by hand', () async {
    final session = EditSession(await route(r1))
      ..set(navTrackSiteField, 's2')
      ..set(navTrackAnchorField, const GeoPoint(1, 2));
    await db.customStatement(
      "UPDATE dives SET site_id = NULL WHERE site_id = 's2'",
    );
    await db.customStatement("DELETE FROM dive_sites WHERE id = 's2'");

    await service.save(
      routeId: r1,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      anchorFromSite: navTrackAnchorFromSite(session),
    );

    final saved = await route(r1);
    expect(saved.siteId, 's1');
    expect(saved.anchor, const GeoPoint(1, 2));
  });
}
