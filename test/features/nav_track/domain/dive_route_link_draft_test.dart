import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

import '../../../helpers/nav_track_fixtures.dart';

void main() {
  final a = testNavTrack('a', diveId: 'd1');
  final b = testNavTrack('b');
  final c = testNavTrack('c');

  test('a fresh draft has no changes', () {
    final draft = DiveRouteLinkDraft.initial([a]);
    expect(draft.current.map((r) => r.id), ['a']);
    expect(draft.toLink, isEmpty);
    expect(draft.toUnlink, isEmpty);
    expect(draft.hasChanges, isFalse);
  });

  test('add links a new route and ignores one already present', () {
    final draft = DiveRouteLinkDraft.initial([a]).add(b).add(b).add(a);
    expect(draft.current.map((r) => r.id), ['a', 'b']);
    expect(draft.toLink, ['b']);
    expect(draft.toUnlink, isEmpty);
  });

  test('remove unlinks an original route and lists it as removed', () {
    final draft = DiveRouteLinkDraft.initial([a]).remove('a');
    expect(draft.current, isEmpty);
    expect(draft.toUnlink, ['a']);
    expect(draft.removed.map((r) => r.id), ['a']);
  });

  test('re-adding a removed route is no net change', () {
    final draft = DiveRouteLinkDraft.initial([a]).remove('a').add(a);
    expect(draft.hasChanges, isFalse);
    expect(draft.removed, isEmpty);
  });

  test('removing a just-added route is no net change', () {
    final draft = DiveRouteLinkDraft.initial([a]).add(b).remove('b');
    expect(draft.hasChanges, isFalse);
  });

  StagedRouteFileUpdate stagedUpdate() =>
      (points: kTestNavTrackPoints, sourceFile: Uint8List.fromList([1, 2]));

  test('updated stages a file update for Save on a route already here', () {
    // Issue #4231: nothing is written until the dive saves.
    final update = stagedUpdate();
    final draft = DiveRouteLinkDraft.initial([a]).updated(a, update);
    expect(draft.current.map((r) => r.id), ['a']);
    expect(draft.toLink, isEmpty);
    expect(draft.toUnlink, isEmpty);
    expect(draft.updates, {'a': update});
    expect(draft.hasChanges, isTrue);
  });

  test('updated adds a route that was not on the dive yet', () {
    final draft = DiveRouteLinkDraft.initial(
      const [],
    ).updated(c, stagedUpdate());
    expect(draft.current.map((r) => r.id), ['c']);
    expect(draft.toLink, ['c']);
    expect(draft.updates.keys, ['c']);
  });

  test('removing an updated route drops its staged update', () {
    final draft = DiveRouteLinkDraft.initial([
      a,
    ]).updated(a, stagedUpdate()).remove('a');
    expect(draft.updates, isEmpty);
    expect(draft.current, isEmpty);
    expect(draft.toUnlink, ['a']);
  });

  test('wasLinkedOnOpen tells original routes from added ones', () {
    final draft = DiveRouteLinkDraft.initial([a]).add(b);
    expect(draft.wasLinkedOnOpen('a'), isTrue);
    expect(draft.wasLinkedOnOpen('b'), isFalse);
  });

  test('never changes when the list it was built from changes', () {
    final linked = <NavTrack>[a];
    final draft = DiveRouteLinkDraft.initial(linked);
    linked.add(b);
    expect(draft.current.map((r) => r.id), ['a']);
    expect(() => draft.current.add(c), throwsUnsupportedError);
  });

  test('each change returns a new draft and leaves the old one alone', () {
    final first = DiveRouteLinkDraft.initial([a]);
    final second = first.add(b);
    expect(identical(first, second), isFalse);
    expect(first.current.map((r) => r.id), ['a']);
  });
}
