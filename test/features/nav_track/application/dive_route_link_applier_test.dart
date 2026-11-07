import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../helpers/nav_track_fixtures.dart';
import '../../../helpers/test_database.dart';

/// Records the order of calls instead of touching a database.
class _RecordingRepository extends NavTrackRepository {
  _RecordingRepository({
    this.alreadyLinked = const {},
    this.diveOf = const {},
    this.gone = const {},
  });

  /// Ids whose staged update finds no row any more.
  final Set<String> gone;

  /// Ids whose `link` reports "already linked elsewhere" (returns false).
  final Set<String> alreadyLinked;

  /// The dive each route is on right now, as `getById` reports it.
  final Map<String, String?> diveOf;
  final calls = <String>[];

  @override
  Future<NavTrack?> getById(String id, {bool includePoints = true}) async =>
      testNavTrack(id, diveId: diveOf[id]);

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    calls.add('link $routeId $diveId ${linkMode.name}');
    return !alreadyLinked.contains(routeId);
  }

  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async =>
      calls.add('unlink $routeId from $onlyFromDiveId');

  @override
  Future<bool> updateImportedData(
    String routeId, {
    required List<NavTrackPoint> points,
    required Uint8List sourceFile,
    String? sourceRef,
  }) async {
    calls.add('update $routeId');
    return !gone.contains(routeId);
  }
}

void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b');
  final c = testNavTrack('c');

  test('unlinks removals before linking additions, as manual links', () async {
    final repository = _RecordingRepository(diveOf: {'a': 'd1'});
    final draft = DiveRouteLinkDraft.initial([a]).remove('a').add(b);

    final skipped = await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: draft,
    );

    expect(repository.calls, ['unlink a from d1', 'link b d1 manual']);
    expect(skipped, isEmpty);
  });

  test('writes nothing for a draft without changes', () async {
    final repository = _RecordingRepository();

    await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial([a]),
    );

    expect(repository.calls, isEmpty);
  });

  test(
    'reports a route something else linked first, without throwing',
    () async {
      final repository = _RecordingRepository(alreadyLinked: {'b'});

      final skipped = await applyDiveRouteLinkDraft(
        repository,
        diveId: 'd1',
        draft: DiveRouteLinkDraft.initial(const []).add(b),
      );

      expect(skipped, ['b']);
    },
  );

  test('unlinks a removal only from this dive, in the same write', () async {
    // The guard lives in the update itself, so sync moving "a" to another
    // dive between a read and the write cannot detach it from that dive.
    final repository = _RecordingRepository();

    await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial([a]).remove('a'),
    );

    expect(repository.calls, ['unlink a from d1']);
  });

  StagedRouteFileUpdate stagedUpdate() =>
      (points: kTestNavTrackPoints, sourceFile: Uint8List.fromList([1, 2]));

  test('writes a staged update before linking the route', () async {
    final repository = _RecordingRepository();

    final skipped = await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial(const []).updated(c, stagedUpdate()),
    );

    expect(repository.calls, ['update c', 'link c d1 manual']);
    expect(skipped, isEmpty);
  });

  test('does not link a route whose staged update found it gone', () async {
    final repository = _RecordingRepository(gone: {'c'});

    final skipped = await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial(const []).updated(c, stagedUpdate()),
    );

    expect(repository.calls, ['update c']);
    expect(skipped, ['c']);
  });

  group('against a real database', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    test('a route imported without a site takes the dive\'s site when '
        'linked', () async {
      final site = await SiteRepository().createSite(
        const DiveSite(id: 'site-final', name: 'Final site'),
      );
      final dive = await DiveRepository().createDive(
        Dive(id: 'd-site', dateTime: DateTime.utc(2025, 8, 22, 10), site: site),
      );
      final routes = NavTrackRepository();
      final routeId = await routes.insertImportedRoute(
        points: kTestNavTrackPoints,
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'site.csv',
      );
      final route = (await routes.getById(routeId, includePoints: false))!;

      await applyDiveRouteLinkDraft(
        routes,
        diveId: dive.id,
        draft: DiveRouteLinkDraft.initial(const []).add(route),
      );

      final linked = await routes.getById(routeId, includePoints: false);
      expect(linked!.siteId, site.id);
    });

    test('a staged update rewrites the route on Save and keeps its link '
        'and primary role', () async {
      final dive = await DiveRepository().createDive(
        Dive(id: 'd-update', dateTime: DateTime.utc(2025, 8, 22, 10)),
      );
      final routes = NavTrackRepository();
      final routeId = await routes.insertImportedRoute(
        points: kTestNavTrackPoints.take(2).toList(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'first.csv',
        diveId: dive.id,
      );
      final linked = await routes.getForDive(dive.id);
      final file = Uint8List.fromList([7, 8, 9]);

      await applyDiveRouteLinkDraft(
        routes,
        diveId: dive.id,
        draft: DiveRouteLinkDraft.initial(linked).updated(linked.single, (
          points: kTestNavTrackPoints,
          sourceFile: file,
        )),
      );

      final after = (await routes.getById(routeId))!;
      expect(after.points, kTestNavTrackPoints);
      expect(after.diveId, dive.id);
      expect(after.isPrimary, isTrue);
      expect(await routes.getSourceFile(routeId), file);
    });
  });
}
