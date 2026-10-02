import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late NavTrackRepository routeRepo;
  late NavTrackMatchService service;

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
    routeRepo = NavTrackRepository();
    service = NavTrackMatchService(
      routeRepository: routeRepo,
      diveRepository: DiveRepository(),
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

  /// A two-sample route from wall-clock second [startSeconds] to
  /// [endSeconds], unlinked unless [diveId] is given.
  Future<String> seedRoute({
    required int startSeconds,
    required int endSeconds,
    String? diveId,
    String? diverId,
  }) => routeRepo.insertImportedRoute(
    points: [
      NavTrackPoint(timestamp: startSeconds, north: 0, east: 0, depth: 5),
      NavTrackPoint(timestamp: endSeconds, north: 10, east: 0, depth: 5),
    ],
    source: NavTrackSource.seacraftEnc,
    sourceRef: 'x.csv',
    diveId: diveId,
    diverId: diverId,
  );

  group('scoped to the active diver', () {
    late NavTrackMatchService mine;

    setUp(() async {
      for (final id in ['me', 'buddy']) {
        await db.customStatement(
          "INSERT INTO divers (id, name, created_at, updated_at) "
          "VALUES ('$id', '$id', 1, 1)",
        );
      }
      mine = NavTrackMatchService(
        routeRepository: routeRepo,
        diveRepository: DiveRepository(),
        currentDiverId: () async => 'me',
      );
    });

    test('suggests the active diver\'s dive when a buddy logged the same '
        'dive, without linking it', () async {
      await seedDive('my-dive', 1000000, exitTimeMs: 2000000, diverId: 'me');
      await seedDive(
        'buddy-dive',
        1000000,
        exitTimeMs: 2000000,
        diverId: 'buddy',
      );
      final routeId = await seedRoute(
        startSeconds: 1400,
        endSeconds: 1600,
        diverId: 'me',
      );

      final result = await mine.sweep();

      expect(result, [(routeId: routeId, suggestedDiveId: 'my-dive')]);
      expect((await routeRepo.getById(routeId))!.diveId, isNull);
    });

    test('never suggests another diver\'s dive', () async {
      // The active diver has a dive, just not one this route overlaps.
      await seedDive('my-other-dive', 9000000, diverId: 'me');
      await seedDive(
        'buddy-dive',
        1000000,
        exitTimeMs: 2000000,
        diverId: 'buddy',
      );
      final routeId = await seedRoute(
        startSeconds: 1400,
        endSeconds: 1600,
        diverId: 'me',
      );

      final result = await mine.sweep();

      expect(result, [(routeId: routeId, suggestedDiveId: null)]);
    });

    test('leaves another diver\'s route out of the report entirely', () async {
      await seedDive('my-dive', 1000000, exitTimeMs: 2000000, diverId: 'me');
      await seedRoute(startSeconds: 1400, endSeconds: 1600, diverId: 'buddy');

      final result = await mine.sweep();

      expect(result, isEmpty);
    });

    test('reports an ownerless route, with no ownership change (nothing is '
        'written any more)', () async {
      await seedDive('my-dive', 1000000, exitTimeMs: 2000000, diverId: 'me');
      final routeId = await seedRoute(startSeconds: 1400, endSeconds: 1600);

      final result = await mine.sweep();

      expect(result, [(routeId: routeId, suggestedDiveId: 'my-dive')]);
      final owner = await db
          .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$routeId'")
          .getSingle();
      expect(owner.read<String?>('diver_id'), isNull);
    });
  });

  test('reports the sole overlapping dive as a suggestion, without linking it '
      '(#2394: a route used to be linked silently the moment exactly one '
      'dive overlapped it)', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);

    final result = await service.sweep();

    expect(result, [(routeId: routeId, suggestedDiveId: 'd1')]);
    final route = await routeRepo.getById(routeId);
    expect(route!.diveId, isNull);
    expect(route.linkMode, isNull);
  });

  test('reports an ambiguous route (two overlapping dives) with no '
      'suggestion', () async {
    await seedDive('d1', 1000000, exitTimeMs: 2000000);
    await seedDive('d2', 1200000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1400, endSeconds: 1600);

    final result = await service.sweep();

    expect(result, [(routeId: routeId, suggestedDiveId: null)]);
    expect((await routeRepo.getById(routeId))!.diveId, isNull);
  });

  test('reports an unmatched route (no dive close in time) with no '
      'suggestion too', () async {
    await seedDive('d1', 9000000, exitTimeMs: 9100000);
    final routeId = await seedRoute(startSeconds: 1000, endSeconds: 1100);

    final result = await service.sweep();

    expect(result, [(routeId: routeId, suggestedDiveId: null)]);
  });

  test('never reports an already-linked route', () async {
    await seedDive('d1', 1000000, exitTimeMs: 1100000);
    await seedDive('d2', 1000000, exitTimeMs: 1100000);
    // Manually linked already, so the sweep must not touch it even though
    // both dives would otherwise make it ambiguous.
    final routeId = await seedRoute(
      startSeconds: 1000,
      endSeconds: 1050,
      diveId: 'd1',
    );

    final result = await service.sweep();

    expect(result, isEmpty);
    expect((await routeRepo.getById(routeId))!.diveId, 'd1');
    expect(
      (await routeRepo.getById(routeId))!.linkMode,
      NavTrackLinkMode.manual,
    );
  });

  test(
    'a sweep is idempotent: running it twice reports the same thing',
    () async {
      await seedDive('d1', 1500000, exitTimeMs: 1800000);
      final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);

      final first = await service.sweep();
      final second = await service.sweep();

      expect(first, [(routeId: routeId, suggestedDiveId: 'd1')]);
      expect(second, first);
    },
  );

  test('limitToRouteIds scopes the sweep to specific routes', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    await seedDive('d2', 5500000, exitTimeMs: 5800000);
    final routeA = await seedRoute(startSeconds: 1600, endSeconds: 1700);
    await seedRoute(startSeconds: 5600, endSeconds: 5700);

    final result = await service.sweep(limitToRouteIds: [routeA]);

    expect(result, [(routeId: routeA, suggestedDiveId: 'd1')]);
  });

  test('limitToDiveIds scopes candidate dives to specific ones', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    await seedDive('d2', 1500000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);

    // Both dives overlap, but only d1 is in scope, so the ambiguity never
    // arises and the route reports the one candidate the sweep could see.
    final result = await service.sweep(limitToDiveIds: ['d1']);

    expect(result, [(routeId: routeId, suggestedDiveId: 'd1')]);
  });

  test('returns immediately when there are no unlinked routes', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    final result = await service.sweep();
    expect(result, isEmpty);
  });

  test(
    'reports a route with no suggestion when there are no dives at all',
    () async {
      final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);
      final result = await service.sweep();
      expect(result, [(routeId: routeId, suggestedDiveId: null)]);
    },
  );
}
