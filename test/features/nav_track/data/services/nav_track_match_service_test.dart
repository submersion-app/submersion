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

  /// A two-sample route from wall-clock second [startSeconds] to
  /// [endSeconds], unlinked unless [diveId] is given.
  Future<String> seedRoute({
    required int startSeconds,
    required int endSeconds,
    String? diveId,
  }) => routeRepo.insertImportedRoute(
    points: [
      NavTrackPoint(timestamp: startSeconds, north: 0, east: 0, depth: 5),
      NavTrackPoint(timestamp: endSeconds, north: 10, east: 0, depth: 5),
    ],
    source: NavTrackSource.seacraftEnc,
    sourceRef: 'x.csv',
    diveId: diveId,
  );

  test('links a route that overlaps exactly one dive', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);

    final result = await service.sweep();

    expect(result.linked, [routeId]);
    expect(result.needsChoice, isEmpty);
    final route = await routeRepo.getById(routeId);
    expect(route!.diveId, 'd1');
    expect(route.linkMode, NavTrackLinkMode.auto);
  });

  test('leaves an ambiguous route (two overlapping dives) unlinked and '
      'reports it', () async {
    await seedDive('d1', 1000000, exitTimeMs: 2000000);
    await seedDive('d2', 1200000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1400, endSeconds: 1600);

    final result = await service.sweep();

    expect(result.linked, isEmpty);
    expect(result.needsChoice, [routeId]);
    expect((await routeRepo.getById(routeId))!.diveId, isNull);
  });

  test('leaves an unmatched route (no dive close in time) unlinked and '
      'reports it as needing a choice too', () async {
    await seedDive('d1', 9000000, exitTimeMs: 9100000);
    final routeId = await seedRoute(startSeconds: 1000, endSeconds: 1100);

    final result = await service.sweep();

    expect(result.linked, isEmpty);
    expect(result.needsChoice, [routeId]);
  });

  test('never reconsiders an already-linked route', () async {
    await seedDive('d1', 1000000, exitTimeMs: 1100000);
    await seedDive('d2', 1000000, exitTimeMs: 1100000);
    // Manually linked already, so the sweep must not touch it even though
    // both dives would otherwise make it needsChoice.
    final routeId = await seedRoute(
      startSeconds: 1000,
      endSeconds: 1050,
      diveId: 'd1',
    );

    final result = await service.sweep();

    expect(result.linked, isEmpty);
    expect(result.needsChoice, isEmpty);
    expect((await routeRepo.getById(routeId))!.diveId, 'd1');
    expect(
      (await routeRepo.getById(routeId))!.linkMode,
      NavTrackLinkMode.manual,
    );
  });

  test('a sweep is idempotent: running it twice changes nothing the '
      'second time', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);

    final first = await service.sweep();
    final second = await service.sweep();

    expect(first.linked, [routeId]);
    expect(second.linked, isEmpty);
    expect(second.needsChoice, isEmpty);
  });

  test('limitToRouteIds scopes the sweep to specific routes', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    await seedDive('d2', 5500000, exitTimeMs: 5800000);
    final routeA = await seedRoute(startSeconds: 1600, endSeconds: 1700);
    final routeB = await seedRoute(startSeconds: 5600, endSeconds: 5700);

    final result = await service.sweep(limitToRouteIds: [routeA]);

    expect(result.linked, [routeA]);
    expect((await routeRepo.getById(routeB))!.diveId, isNull);
  });

  test('limitToDiveIds scopes candidate dives to specific ones', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    await seedDive('d2', 1500000, exitTimeMs: 1800000);
    final routeId = await seedRoute(startSeconds: 1600, endSeconds: 1700);

    // Both dives overlap, but only d1 is in scope, so the ambiguity never
    // arises and the route links to the one candidate the sweep could see.
    final result = await service.sweep(limitToDiveIds: ['d1']);

    expect(result.linked, [routeId]);
    expect((await routeRepo.getById(routeId))!.diveId, 'd1');
  });

  test('returns immediately when there are no unlinked routes', () async {
    await seedDive('d1', 1500000, exitTimeMs: 1800000);
    final result = await service.sweep();
    expect(result.linked, isEmpty);
    expect(result.needsChoice, isEmpty);
  });

  test('returns immediately when there are no dives at all', () async {
    await seedRoute(startSeconds: 1600, endSeconds: 1700);
    final result = await service.sweep();
    expect(result.linked, isEmpty);
    expect(result.needsChoice, isEmpty);
  });
}
