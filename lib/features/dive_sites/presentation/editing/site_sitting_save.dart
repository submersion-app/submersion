import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_edit_save_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_start.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

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
  Set<String>? privateCards,
}) async {
  final ({DiveSite before, DiveSite after})? result;
  try {
    result = await _save(
      session,
      service,
      actingDiverId: actingDiverId,
      privateCards: privateCards,
    );
  } on SiteEditRefused {
    // The page stays unlocked with the sitting, and says why.
    throw RecordSittingRefusal((l10n) => l10n.diveSites_edit_saveRefused);
  }
  if (result == null) return null;
  await _mediaAfterCommit(session);
  return result;
}

/// A new site's sitting (issue #4527, plan 6): the site created with
/// everything the sitting held, in one transaction
/// ([SiteEditSaveService.create]), then what the media write left for
/// after the commit, each step guarded. A seed with no diver takes
/// [activeDiverId]. Returns the site as stored.
Future<DiveSite> createSiteSitting(
  EditSession<DiveSite> session,
  SiteEditSaveService service, {
  String? activeDiverId,
}) async {
  var site = session.applyTo(session.stored);
  if (site.diverId == null && activeDiverId != null) {
    site = site.copyWith(diverId: activeDiverId);
  }
  final created = await undoMediaOnFailure(
    session,
    () => service.create(
      site: site,
      changedCardIds: session.changedCardIds,
      // Everything held points at the site: all of it runs after the row.
      alsoWrite: session.hasHeldWrites
          ? () async {
              await session.runHeldWrites(beforeRecord: true);
              await session.runHeldWrites();
            }
          : null,
    ),
  );
  await _mediaAfterCommit(session);
  return created;
}

/// Uploads, and the remote deletes the unlinks held, once the sitting has
/// committed: each on its own, so one that fails never reads as a failed
/// save.
Future<void> _mediaAfterCommit(EditSession<DiveSite> session) async {
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
}

/// [privateCards], for a library reader's Send (issue #4527, plan 5),
/// writes only those cards: the site's private fields, and the held
/// changes of those cards alone.
Future<({DiveSite before, DiveSite after})?> _save(
  EditSession<DiveSite> session,
  SiteEditSaveService service, {
  String? actingDiverId,
  Set<String>? privateCards,
}) {
  final private = privateCards;
  final changed = private == null
      ? session.changedCardIds
      : session.changedCardIds.where(private.contains).toSet();
  return undoMediaOnFailure(
    session,
    () => service.save(
      // The site the sitting was opened on, whatever the page shows by the
      // time the write is asked for.
      siteId: session.stored.id,
      apply: session.applyTo,
      changedCardIds: changed,
      actingDiverId: actingDiverId,
      writeFirst: session.hasHeldWritesBeforeRecord
          ? () => session.runHeldWrites(beforeRecord: true, cardIds: private)
          : null,
      alsoWrite: session.hasHeldWrites
          ? () => session.runHeldWrites(cardIds: private)
          : null,
      // A reader's held change of one of their cards is a change in its
      // own right; the library's fields are stamped only for an edit.
      alsoWriteIsAChange: private == null
          ? session.hasHeldChanges
          : session.heldChangeCardIds.any(private.contains),
      heldLibraryFields: private == null
          ? () => siteLibraryFields(session)
          : null,
      privateOnly: private != null,
    ),
  );
}
