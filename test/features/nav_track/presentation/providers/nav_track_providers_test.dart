import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';

import '../../../../helpers/test_database.dart';

List<NavTrackPoint> _samplePoints({int count = 5}) => [
  for (var i = 0; i < count; i++)
    NavTrackPoint(
      timestamp: 1700000000 + i * 10,
      north: i * 10.0,
      east: 0,
      depth: 5,
    ),
];

Future<void> _insertMinimalDive(AppDatabase db, String id) {
  return db.customStatement(
    "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
    "VALUES ('$id', 1700000000000, 1, 1)",
  );
}

void main() {
  late AppDatabase db;
  late NavTrackRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = NavTrackRepository();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('allNavTracksProvider lists unlinked routes first', () async {
    final unlinkedId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'unlinked.csv',
    );
    await _insertMinimalDive(db, 'dive-1');
    final linkedId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'linked.csv',
      diveId: 'dive-1',
    );

    final all = await container.read(allNavTracksProvider.future);

    expect(all.map((t) => t.id), [unlinkedId, linkedId]);
  });

  test('unlinkedNavTracksProvider excludes linked routes', () async {
    await _insertMinimalDive(db, 'dive-1');
    await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'linked.csv',
      diveId: 'dive-1',
    );
    final unlinkedId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'unlinked.csv',
    );

    final unlinked = await container.read(unlinkedNavTracksProvider.future);

    expect(unlinked.map((t) => t.id), [unlinkedId]);
  });

  test('navTracksForDiveProvider returns only that dive\'s routes', () async {
    await _insertMinimalDive(db, 'dive-1');
    await _insertMinimalDive(db, 'dive-2');
    final forDive1 = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'dive1.csv',
      diveId: 'dive-1',
    );
    await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'dive2.csv',
      diveId: 'dive-2',
    );

    final routes = await container.read(
      navTracksForDiveProvider('dive-1').future,
    );

    expect(routes.map((t) => t.id), [forDive1]);
  });

  test('primaryNavTrackForDiveProvider returns null when unlinked', () async {
    final result = await container.read(
      primaryNavTrackForDiveProvider('dive-none').future,
    );

    expect(result, isNull);
  });

  test(
    'primaryNavTrackForDiveProvider returns the primary route, hydrated',
    () async {
      await _insertMinimalDive(db, 'dive-1');
      final points = _samplePoints();
      final id = await repo.insertImportedRoute(
        points: points,
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'primary.csv',
        diveId: 'dive-1',
      );

      final route = await container.read(
        primaryNavTrackForDiveProvider('dive-1').future,
      );

      expect(route, isNotNull);
      expect(route!.id, id);
      expect(route.points, hasLength(points.length));
    },
  );

  test('navTrackByIdProvider hydrates points', () async {
    final points = _samplePoints();
    final id = await repo.insertImportedRoute(
      points: points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'byid.csv',
    );

    final route = await container.read(navTrackByIdProvider(id).future);

    expect(route, isNotNull);
    expect(route!.points, hasLength(points.length));
  });

  test(
    'allNavTracksProvider invalidates when the repository changes',
    () async {
      final before = await container.read(allNavTracksProvider.future);
      expect(before, isEmpty);

      // Subscribe so invalidateSelfWhen's listener is attached and stays live.
      final sub = container.listen(
        allNavTracksProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await repo.insertImportedRoute(
        points: _samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'new.csv',
      );

      final after = await container.read(allNavTracksProvider.future);
      expect(after, hasLength(1));
    },
  );
  // Every hydrated read decodes the whole points blob (gzip plus JSON, up to
  // kMaxNavTrackPointCount samples), so a write to one route must not make
  // every other open route decode its blob again.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('navTrackByIdProvider reloads for its own route only, not for a write '
      'to another route', () async {
    final watchedId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'watched.csv',
    );
    final otherId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'other.csv',
    );
    await container.read(navTrackByIdProvider(watchedId).future);
    var notifications = 0;
    final sub = container.listen(
      navTrackByIdProvider(watchedId),
      (_, _) => notifications++,
    );
    addTearDown(sub.close);

    await repo.rename(otherId, 'Renamed elsewhere');
    await settle();
    expect(notifications, 0);

    await repo.rename(watchedId, 'Renamed here');
    await settle();
    final route = await container.read(navTrackByIdProvider(watchedId).future);
    expect(route!.name, 'Renamed here');
  });

  test('primaryNavTrackForDiveProvider does not reload when a non-primary '
      'sibling changes', () async {
    await _insertMinimalDive(db, 'dive-1');
    await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'primary.csv',
      diveId: 'dive-1',
    );
    final siblingId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'sibling.csv',
      diveId: 'dive-1',
    );
    await container.read(primaryNavTrackForDiveProvider('dive-1').future);
    var notifications = 0;
    final sub = container.listen(
      primaryNavTrackForDiveProvider('dive-1'),
      (_, _) => notifications++,
    );
    addTearDown(sub.close);

    await repo.rename(siblingId, 'Renamed sibling');
    await settle();

    expect(notifications, 0);
  });

  test('primaryNavTrackForDiveProvider follows a primary switch', () async {
    await _insertMinimalDive(db, 'dive-1');
    await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'primary.csv',
      diveId: 'dive-1',
    );
    final siblingId = await repo.insertImportedRoute(
      points: _samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'sibling.csv',
      diveId: 'dive-1',
    );
    await container.read(primaryNavTrackForDiveProvider('dive-1').future);
    final sub = container.listen(
      primaryNavTrackForDiveProvider('dive-1'),
      (_, _) {},
    );
    addTearDown(sub.close);

    await repo.setPrimary(siblingId);
    await settle();

    final primary = await container.read(
      primaryNavTrackForDiveProvider('dive-1').future,
    );
    expect(primary!.id, siblingId);
  });
}
