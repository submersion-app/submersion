import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_match_service.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';

class _Gps extends GpsTrackMatchService {
  _Gps(this.calls, {this.result = const [], this.fail = false})
    : super(
        trackRepository: GpsTrackRepository(),
        diveRepository: DiveRepository(),
      );
  final List<String> calls;
  final List<String> result;
  final bool fail;

  @override
  Future<List<String>> sweep({List<String>? limitToIds}) async {
    calls.add('gps');
    if (fail) throw StateError('gps failed');
    return result;
  }
}

class _Underwater extends NavTrackMatchService {
  _Underwater(this.calls, {this.linked = const [], this.fail = false})
    : super(
        routeRepository: NavTrackRepository(),
        diveRepository: DiveRepository(),
      );
  final List<String> calls;
  final List<String> linked;
  final bool fail;

  @override
  Future<({List<String> linked, List<String> needsChoice})> sweep({
    List<String>? limitToRouteIds,
    List<String>? limitToDiveIds,
  }) async {
    calls.add('underwater');
    if (fail) throw StateError('underwater failed');
    return (linked: linked, needsChoice: const <String>[]);
  }
}

void main() {
  test('runs the GPS sweep, then the underwater sweep', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls, result: const ['d1', 'd2']),
      underwater: _Underwater(calls, linked: const ['r1']),
    ).matchAll();
    expect(calls, ['gps', 'underwater']);
    expect(outcome.positionedDiveIds, ['d1', 'd2']);
    expect(outcome.linkedUnderwaterIds, ['r1']);
    expect(outcome.anyFailed, isFalse);
    expect(outcome.matchedAnything, isTrue);
  });

  test('a failing GPS sweep still runs the underwater sweep', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls, fail: true),
      underwater: _Underwater(calls, linked: const ['r1']),
    ).matchAll();
    expect(calls, ['gps', 'underwater']);
    expect(outcome.anyFailed, isTrue);
    expect(outcome.linkedUnderwaterIds, ['r1']);
  });

  test('a failing underwater sweep keeps the GPS result', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls, result: const ['d1']),
      underwater: _Underwater(calls, fail: true),
    ).matchAll();
    expect(outcome.anyFailed, isTrue);
    expect(outcome.positionedDiveIds, ['d1']);
  });

  test('nothing new is reported as such', () async {
    final calls = <String>[];
    final outcome = await TracksMatchController(
      gps: _Gps(calls),
      underwater: _Underwater(calls),
    ).matchAll();
    expect(outcome.matchedAnything, isFalse);
    expect(outcome.anyFailed, isFalse);
  });
}
