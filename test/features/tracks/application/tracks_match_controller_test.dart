import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';

class _Gps extends GpsTrackMatchService {
  _Gps({this.result = const [], this.fail = false})
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );
  final List<String> result;
  final bool fail;

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    if (fail) throw StateError('gps failed');
    return result;
  }
}

void main() {
  // Underwater tracks are only ever suggested, never linked by a sweep
  // (#2394), so Match positions dives from GPS tracks alone.
  test('reports the dives the GPS sweep positioned', () async {
    final outcome = await TracksMatchController(
      gps: _Gps(result: const ['d1', 'd2']),
    ).matchAll();
    expect(outcome.positionedDiveIds, ['d1', 'd2']);
    expect(outcome.failed, isFalse);
  });

  test('a failing sweep is reported, not thrown', () async {
    final outcome = await TracksMatchController(
      gps: _Gps(fail: true),
    ).matchAll();
    expect(outcome.failed, isTrue);
    expect(outcome.positionedDiveIds, isEmpty);
  });
}
