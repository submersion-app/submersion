import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// Writes [draft] for [diveId] once the dive row exists. Removals are
/// unlinked before additions are linked, so `link` re-decides the dive's
/// primary route against what is actually left.
///
/// Returns the ids `link` skipped because the route was already linked by
/// the time this ran (synced from another device, or auto-linked when a new
/// dive was created). Repository errors propagate to the caller.
Future<List<String>> applyDiveRouteLinkDraft(
  NavTrackRepository repository, {
  required String diveId,
  required DiveRouteLinkDraft draft,
}) async {
  for (final routeId in draft.toUnlink) {
    await repository.unlink(routeId);
  }
  final skipped = <String>[];
  for (final routeId in draft.toLink) {
    final linked = await repository.link(
      routeId,
      diveId,
      linkMode: NavTrackLinkMode.manual,
    );
    if (!linked) skipped.add(routeId);
  }
  return List.unmodifiable(skipped);
}
