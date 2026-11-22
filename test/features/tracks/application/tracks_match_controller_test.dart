import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
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

/// Records each link; [missingDives] are gone, [alreadyLinked] were linked
/// meanwhile, and [failing] throw.
class _Routes extends NavTrackRepository {
  _Routes({
    this.missingDives = const {},
    this.alreadyLinked = const {},
    this.failing = const {},
  });

  final Set<String> missingDives;
  final Set<String> alreadyLinked;
  final Set<String> failing;
  final linked = <(String, String, NavTrackLinkMode)>[];

  @override
  Future<bool> diveExists(String diveId) async =>
      !missingDives.contains(diveId);

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    if (failing.contains(routeId)) throw StateError('database locked');
    if (alreadyLinked.contains(routeId)) return false;
    linked.add((routeId, diveId, linkMode));
    return true;
  }
}

NavTrack _route(String id, DateTime start) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(minutes: 40)).millisecondsSinceEpoch,
  pointCount: 2,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Dive _dive(String id, DateTime entry) => Dive(
  id: id,
  dateTime: entry,
  entryTime: entry,
  exitTime: entry.add(const Duration(hours: 1)),
);

final _morning = DateTime.utc(2026, 8, 22, 10);
final _afternoon = DateTime.utc(2026, 8, 22, 14);

TracksMatchController _controller({
  _Gps? gps,
  _Routes? routes,
  List<NavTrack> unlinked = const [],
  List<Dive> dives = const [],
  bool failRoutes = false,
}) => TracksMatchController(
  gps: gps ?? _Gps(),
  routes: routes ?? _Routes(),
  unlinkedRoutes: () async {
    if (failRoutes) throw StateError('routes failed');
    return unlinked;
  },
  dives: () async => dives,
);

void main() {
  test('reports the dives the GPS sweep positioned', () async {
    final outcome = await _controller(
      gps: _Gps(result: const ['d1', 'd2']),
    ).matchAll();
    expect(outcome.positionedDiveIds, ['d1', 'd2']);
    expect(outcome.failed, isFalse);
  });

  test('a failing sweep is reported, not thrown', () async {
    final outcome = await _controller(gps: _Gps(fail: true)).matchAll();
    expect(outcome.failed, isTrue);
    expect(outcome.positionedDiveIds, isEmpty);
  });

  // #4851: Match proposes underwater tracks for linking; it links none
  // itself, since the diver confirms them first (#2394).
  test('proposes each unlinked underwater track with one overlapping dive, '
      'and links nothing', () async {
    final routes = _Routes();
    final outcome = await _controller(
      routes: routes,
      unlinked: [_route('r1', _morning), _route('r2', DateTime.utc(2027))],
      dives: [_dive('d1', _morning), _dive('d2', _afternoon)],
    ).matchAll();
    expect(
      [for (final p in outcome.linkProposals) (p.route.id, p.dive.id)],
      [('r1', 'd1')],
    );
    expect(routes.linked, isEmpty);
  });

  test('a failure reading the tracks is reported, keeping what the GPS sweep '
      'positioned', () async {
    final outcome = await _controller(
      gps: _Gps(result: const ['d1']),
      failRoutes: true,
    ).matchAll();
    expect(outcome.failed, isTrue);
    expect(outcome.positionedDiveIds, ['d1']);
    expect(outcome.linkProposals, isEmpty);
  });

  group('linkProposals', () {
    final proposals = [
      (route: _route('r1', _morning), dive: _dive('d1', _morning)),
      (route: _route('r2', _afternoon), dive: _dive('d2', _afternoon)),
    ];

    test('links every proposal as a match, and counts them', () async {
      final routes = _Routes();
      final result = await _controller(routes: routes).linkProposals(proposals);
      expect(routes.linked, [
        ('r1', 'd1', NavTrackLinkMode.auto),
        ('r2', 'd2', NavTrackLinkMode.auto),
      ]);
      expect(result.linked, 2);
      expect(result.failed, isFalse);
    });

    test('skips a dive deleted meanwhile and a track linked meanwhile, '
        'without counting them', () async {
      final routes = _Routes(missingDives: {'d1'}, alreadyLinked: {'r2'});
      final result = await _controller(routes: routes).linkProposals(proposals);
      expect(routes.linked, isEmpty);
      expect(result.linked, 0);
      expect(result.failed, isFalse);
    });

    test('a failing link is reported, and the others still link', () async {
      final routes = _Routes(failing: {'r1'});
      final result = await _controller(routes: routes).linkProposals(proposals);
      expect(routes.linked, [('r2', 'd2', NavTrackLinkMode.auto)]);
      expect(result.linked, 1);
      expect(result.failed, isTrue);
    });
  });
}
