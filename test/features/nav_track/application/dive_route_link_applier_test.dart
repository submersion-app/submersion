import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

import '../../../helpers/nav_track_fixtures.dart';

/// Records the order of calls instead of touching a database.
class _RecordingRepository extends NavTrackRepository {
  _RecordingRepository({this.alreadyLinked = const {}});

  /// Ids whose `link` reports "already linked elsewhere" (returns false).
  final Set<String> alreadyLinked;
  final calls = <String>[];

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
  Future<void> unlink(String routeId) async => calls.add('unlink $routeId');
}

void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b');

  test('unlinks removals before linking additions, as manual links', () async {
    final repository = _RecordingRepository();
    final draft = DiveRouteLinkDraft.initial([a]).remove('a').add(b);

    final skipped = await applyDiveRouteLinkDraft(
      repository,
      diveId: 'd1',
      draft: draft,
    );

    expect(repository.calls, ['unlink a', 'link b d1 manual']);
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
}
