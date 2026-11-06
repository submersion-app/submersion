import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../helpers/test_database.dart';

/// A route's original file (issue #4231) rides in the same delta as its
/// points, so the oversized-changeset guard has to count it too.
void main() {
  setUp(() async {
    await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 1000);
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('counts a route\'s stored original file', () async {
    final serializer = SyncDataSerializer();
    final repo = NavTrackRepository();
    const points = [
      NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 2),
      NavTrackPoint(timestamp: 2, north: 1, east: 0, depth: 3),
    ];
    final id = await repo.insertImportedRoute(
      points: points,
      source: NavTrackSource.seacraftEnc,
      sourceRef: '011.DAT.csv',
    );
    final withoutFile = await serializer.pendingSeriesBlobBytes(null);

    // Noise does not compress, so the stored blob stays about this large.
    final random = math.Random(4231);
    final file = Uint8List.fromList([
      for (var i = 0; i < 20000; i++) random.nextInt(256),
    ]);
    await repo.updateImportedData(id, points: points, sourceFile: file);

    expect(
      await serializer.pendingSeriesBlobBytes(null),
      greaterThan(withoutFile + 19000),
    );
  });
}
