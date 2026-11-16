import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/nav_track/application/dive_route_link_applier.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/dive_route_link_draft.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveRouteLinksSitting');

/// The held change of the Underwater track card: routes linked, unlinked
/// and made primary in the sitting.
const String routeLinksKey = 'routeLinks';

/// The routes the save could not link, kept for the message the page shows
/// after it (issue #4527, plan 6).
const String routeLinksSkippedKey = 'routeLinks.skipped';

const String _draftKey = 'routeLinks.draft';
const String _repoKey = 'routeLinks.repo';

/// The sitting's route draft, or null before it loads.
DiveRouteLinkDraft? sittingRouteDraft(EditSession<Dive> session) =>
    session.isDisposed ? null : session.recall<DiveRouteLinkDraft>(_draftKey);

/// Reads the routes linked to the dive, once per sitting. Tracked.
void loadDiveRouteLinks(EditSession<Dive> session, ProviderRead read) {
  if (!session.firstTime(_draftKey)) return;
  final repository = read(navTrackRepositoryProvider);
  session.remember(_repoKey, repository);
  final diveId = session.stored.id;
  session.track(() async {
    try {
      final linked = await repository.getForDive(diveId);
      if (session.isDisposed || session.isFrozen) return;
      session.remember(_draftKey, DiveRouteLinkDraft.initial(linked));
    } catch (error, stackTrace) {
      _log.warning(
        'Reading the routes for a sitting failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }());
}

/// Replaces the sitting's draft. One with no changes releases the held
/// change.
void setRouteDraft(EditSession<Dive> session, DiveRouteLinkDraft next) {
  if (session.isDisposed || session.isFrozen) return;
  final repository = session.recall<NavTrackRepository>(_repoKey);
  if (repository == null || sittingRouteDraft(session) == null) return;
  session.remember(_draftKey, next);
  if (!next.hasChanges) {
    session.releaseWrite(routeLinksKey);
    return;
  }
  session.holdChange(
    routeLinksKey,
    cardId: DiveDetailSectionId.navTrack.name,
    write: () async {
      // A planned dive has no route: its links are not saved (plan 4).
      if (session.working.isPlanned) return;
      final draft = sittingRouteDraft(session);
      if (draft == null || !draft.hasChanges) return;
      final skipped = await applyDiveRouteLinkDraft(
        repository,
        diveId: session.stored.id,
        draft: draft,
      );
      session.remember(routeLinksSkippedKey, skipped);
    },
  );
}
