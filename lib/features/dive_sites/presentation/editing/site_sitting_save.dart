import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('SiteSittingSave');

/// Saves [session] through [service] as the site page saves it (issue
/// #4527, phase 2): the site's changes and every held write in one
/// transaction and one History entry, the library stamped once that has
/// committed, what the media write did outside the database taken back if
/// it does not, and what the media write left for after the commit done,
/// each step guarded. Returns the site before and after, or null when
/// nothing changed.
Future<({DiveSite before, DiveSite after})?> saveSiteSitting(
  EditSession<DiveSite> session,
  SiteEditSaveService service, {
  String? actingDiverId,
}) async {
  // Noted afresh by this attempt's held writes.
  clearSiteLibraryFields(session);
  final result = await undoMediaOnFailure(
    session,
    () => service.save(
      // The site the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      siteId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      actingDiverId: actingDiverId,
      writeFirst: session.hasHeldWritesBeforeRecord
          ? () => session.runHeldWrites(beforeRecord: true)
          : null,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
      heldLibraryFields: () => siteLibraryFields(session),
    ),
  );
  if (result == null) return null;
  // Uploads, the remote deletes the unlinks held: each on its own.
  for (final step in mediaAfterCommit(session)) {
    try {
      await step();
    } catch (error, stackTrace) {
      _log.error(
        'Media follow-up after saving site ${session.stored.id} failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  return result;
}
