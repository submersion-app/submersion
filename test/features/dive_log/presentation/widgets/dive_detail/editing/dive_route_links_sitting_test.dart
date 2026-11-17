import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_route_links_sitting.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/nav_track_fixtures.dart';

class _Repo extends NavTrackRepository {
  _Repo(this.linked);
  final List<NavTrack> linked;
  final calls = <String>[];

  @override
  Future<List<NavTrack>> getForDive(
    String diveId, {
    bool includePoints = false,
  }) async => linked;

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    calls.add('link $routeId');
    return true;
  }

  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async =>
      calls.add('unlink $routeId');

  @override
  Future<bool> setPrimary(String routeId, {String? onlyForDiveId}) async {
    calls.add('primary $routeId');
    return true;
  }
}

/// A dive's route links held in a sitting (issue #4527, plan 6).
void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b', diveId: 'd1', isPrimary: false);
  final c = testNavTrack('c');
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026));

  late _Repo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _Repo([a, b]);
    container = ProviderContainer(
      overrides: [navTrackRepositoryProvider.overrideWithValue(repo)],
    );
  });
  tearDown(() => container.dispose());

  Future<EditSession<Dive>> started(Dive d) async {
    final session = EditSession<Dive>(d);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    loadDiveRouteLinks(session, container.read);
    await session.settled();
    return session;
  }

  test('a route unlinked, one linked and another made primary: written at '
      'Save', () async {
    final session = await started(dive);
    final draft = sittingRouteDraft(session)!;
    setRouteDraft(session, draft.remove('a').add(c).withPrimary('b'));
    expect(session.changedCardIds, {'navTrack'});

    await session.runHeldWrites();
    expect(repo.calls, ['unlink a', 'link c', 'primary b']);
  });

  test('no changes: released, nothing written', () async {
    final session = await started(dive);
    final draft = sittingRouteDraft(session)!;
    setRouteDraft(session, draft.add(c));
    setRouteDraft(session, draft);
    expect(session.isDirty, isFalse);
  });

  test('Cancel writes nothing', () async {
    final session = await started(dive);
    setRouteDraft(session, sittingRouteDraft(session)!.add(c));
    session.dispose();
    expect(repo.calls, isEmpty);
  });

  test('a planned dive: the held draft is not written', () async {
    final session = await started(dive.copyWith(isPlanned: true));
    setRouteDraft(session, sittingRouteDraft(session)!.add(c));
    await session.runHeldWrites();
    expect(repo.calls, isEmpty);
  });
}
