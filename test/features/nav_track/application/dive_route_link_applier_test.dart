import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

import '../../../helpers/nav_track_fixtures.dart';
import '../../../helpers/test_database.dart';

/// Records the order of calls instead of touching a database.
class _RecordingRepository extends NavTrackRepository {
  _RecordingRepository({this.alreadyLinked = const {}, this.diveOf = const {}});

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
  Future<void> replace(String routeId, {required String withRouteId}) async =>
      calls.add('replace $routeId $withRouteId');
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

  test(
    'skips the replacement when the re-import was linked elsewhere first',
    () async {
      final repository = _RecordingRepository(alreadyLinked: {'c'});

      final skipped = await applyDiveRouteLinkDraft(
        repository,
        diveId: 'd1',
        draft: DiveRouteLinkDraft.initial([a]).replaced('a', c),
      );

      // The dive keeps its original route rather than losing it to a delete.
      expect(repository.calls, ['link c d1 manual']);
      expect(skipped, ['c']);
    },
  );

  test('links a re-import before replacing the route it supersedes', () async {
    final repository = _RecordingRepository(diveOf: {'a': 'd1'});

    await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: DiveRouteLinkDraft.initial([a]).replaced('a', c),
    );

    expect(repository.calls, ['link c d1 manual', 'replace a c']);
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

    test('a re-import of the primary route takes over as primary', () async {
      final dive = await DiveRepository().createDive(
        Dive(id: 'd-primary', dateTime: DateTime.utc(2025, 8, 22, 10)),
      );
      final routes = NavTrackRepository();
      Future<String> insert(String name, {String? diveId}) =>
          routes.insertImportedRoute(
            points: kTestNavTrackPoints,
            source: NavTrackSource.seacraftEnc,
            sourceRef: '$name.csv',
            name: name,
            diveId: diveId,
          );
      final primaryId = await insert('first', diveId: dive.id);
      final siblingId = await insert('second', diveId: dive.id);
      final reImportId = await insert('first again');
      final linked = await routes.getForDive(dive.id);
      expect(linked.firstWhere((r) => r.id == primaryId).isPrimary, isTrue);

      final reImport = (await routes.getById(
        reImportId,
        includePoints: false,
      ))!;
      await applyDiveRouteLinkDraft(
        routes,
        diveId: dive.id,
        draft: DiveRouteLinkDraft.initial(linked).replaced(primaryId, reImport),
      );

      final after = await routes.getForDive(dive.id);
      expect(after.map((r) => r.id).toSet(), {reImportId, siblingId});
      expect(after.firstWhere((r) => r.id == reImportId).isPrimary, isTrue);
      expect(after.firstWhere((r) => r.id == siblingId).isPrimary, isFalse);
      expect(await routes.getById(primaryId, includePoints: false), isNull);
    });
  });
}
