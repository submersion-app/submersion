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
}
