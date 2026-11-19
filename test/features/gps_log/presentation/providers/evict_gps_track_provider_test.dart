import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

/// Records evictions instead of touching the local cache database.
class _RecordingCache extends TrackGeometryCacheRepository {
  final evicted = <String>[];

  @override
  Future<void> invalidate(String trackId) async => evicted.add(trackId);
}

/// After a GPS track page saves a trim it drops the cached geometry; the
/// page reads the track back itself, so the drop must not decode the points
/// blob a second time (issue #4527, plan 5).
void main() {
  test('drops the cached geometry without rereading the track', () async {
    final cache = _RecordingCache();
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        trackGeometryCacheRepositoryProvider.overrideWithValue(cache),
        gpsTrackDetailProvider('t1').overrideWith((ref) async {
          reads++;
          return const GpsTrack(id: 't1', startTime: 0);
        }),
      ],
    );
    addTearDown(container.dispose);
    final keep = container.listen(gpsTrackDetailProvider('t1'), (_, _) {});
    addTearDown(keep.close);
    await container.read(gpsTrackDetailProvider('t1').future);
    expect(reads, 1);

    await container.read(evictGpsTrackProvider)('t1');
    await container.read(gpsTrackDetailProvider('t1').future);

    expect(cache.evicted, ['t1']);
    expect(reads, 1);
  });
}
