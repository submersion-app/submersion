import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// Writes [draft] for [diveId] once the dive row exists. Removals are
/// unlinked before additions are linked, so `link` re-decides the dive's
/// primary route against what is actually left. A removal is unlinked only
/// while it is still on this dive (the check is part of the write), so one
/// that sync moved elsewhere while the form was open is left alone. Staged
/// file updates (issue #4231) are written next, before any link: a route
/// deleted meanwhile is not linked either.
///
/// Returns the ids that did not end up on this dive: `link` skipped them
/// because the route was already linked by the time this ran (synced from
/// another device, or auto-linked when a new dive was created), or the
/// route was gone when its staged update was written. Repository errors
/// propagate to the caller.
Future<List<String>> applyDiveRouteLinkDraft(
  NavTrackRepository repository, {
  required String diveId,
  required DiveRouteLinkDraft draft,
}) async {
  for (final routeId in draft.toUnlink) {
    await repository.unlink(routeId, onlyFromDiveId: diveId);
  }
  final skipped = <String>[];
  for (final MapEntry(key: routeId, value: update) in draft.updates.entries) {
    final updated = await repository.updateImportedData(
      routeId,
      points: update.points,
      sourceFile: update.sourceFile,
    );
    if (!updated) skipped.add(routeId);
  }
  for (final routeId in draft.toLink) {
    if (skipped.contains(routeId)) continue;
    final linked = await repository.link(
      routeId,
      diveId,
      linkMode: NavTrackLinkMode.manual,
    );
    if (!linked) skipped.add(routeId);
  }
  return List.unmodifiable(skipped);
}
