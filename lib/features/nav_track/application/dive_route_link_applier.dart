import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// Writes [draft] for [diveId] once the dive row exists. Removals are
/// unlinked before additions are linked, so `link` re-decides the dive's
/// primary route against what is actually left. A removal that is no longer
/// on this dive (moved by sync while the form was open) is left alone.
/// Staged re-imports replace their old route last, once linked, so the
/// repository hands the old route's primary role over before deleting it.
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
    final route = await repository.getById(routeId, includePoints: false);
    if (route?.diveId != diveId) continue;
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
  for (final MapEntry(key: oldId, value: newId) in draft.replacements.entries) {
    await repository.replace(oldId, withRouteId: newId);
  }
  return List.unmodifiable(skipped);
}
