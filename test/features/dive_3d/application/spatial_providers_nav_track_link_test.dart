import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../helpers/test_database.dart';

/// End-to-end regression for issue item 4: earlier tests of
/// `spatialReckonedPathProvider`'s route-vs-dead-reckoning branch all
/// override `primaryNavTrackForDiveProvider` directly with a fake `NavTrack`
/// (see `test/helpers/mock_providers.dart`'s `primaryNavTrack` parameter),
/// which proves that branch's own logic but never exercises the real chain
/// a diver actually triggers: linking a route to a dive through
/// `NavTrackRepository`, which `navTracksForDiveProvider` and
/// `primaryNavTrackForDiveProvider` read from the real database. This test
/// goes through that whole chain with no provider overrides at all.
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

  test('linking a route to a dive makes its 3D scene provider return the '
      'measured route, not a dead-reckoned estimate', () async {
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
      "VALUES ('d1', 1700000000000, 1, 1)",
    );

    final points = [
      for (var i = 0; i < 5; i++)
        NavTrackPoint(
          timestamp: 1700000000 + i * 10,
          north: i * 10.0,
          east: 0,
          depth: 5,
        ),
    ];
    final routeId = await repo.insertImportedRoute(
      points: points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: 'real.csv',
    );
    await repo.link(routeId, 'd1', linkMode: NavTrackLinkMode.manual);

    final path = await container.read(spatialReckonedPathProvider('d1').future);

    expect(path, isNotNull);
    expect(path!.provenance, PathProvenance.measured);
    expect(path.points, hasLength(points.length));
  });
}
