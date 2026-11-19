import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A sitting's Save refused because the profile may no longer edit the
/// site (its library role was taken away since the sitting began): nothing
/// was written.
class SiteEditRefused implements Exception {
  const SiteEditRefused(this.siteId);

  final String siteId;

  @override
  String toString() => 'SiteEditRefused($siteId)';
}

/// Saves one editing sitting on a site (issue #4527, phase 2).
///
/// The diver's changes are applied to the site as it is stored at the
/// moment of saving, not as it was when the sitting began, so a value
/// changed underneath meanwhile (a sync) on a card the diver never touched
/// is not written back over. Everything is written in one database
/// transaction and one change log operation ([writeRecordSitting]), so the
/// sitting is one History entry that reverts as a unit.
class SiteEditSaveService {
  SiteEditSaveService(this._sites, {LibraryEditStamper? stamper})
    : _stamper = stamper ?? LibraryEditStamper();

  final SiteRepository _sites;
  final LibraryEditStamper _stamper;
  final _log = LoggerService.forClass(SiteEditSaveService);

  /// Applies [apply] to the site as stored now and writes the result
  /// through [SiteRepository.updateSite], for [actingDiverId], so a library
  /// site's private fields are kept as they are from any other save. Its
  /// library stamp is written once the sitting has committed
  /// ([SiteRepository.stampLibraryEdit]), best effort.
  ///
  /// [changedCardIds] names the cards the sitting changed, for its History
  /// label. Returns the site before and after, or null when [apply] changed
  /// nothing. Throws [StateError] when the site no longer exists.
  /// [writeFirst], [alsoWrite] and [alsoWriteIsAChange] are the sitting's
  /// held writes, as [writeRecordSitting] runs them. [heldLibraryFields],
  /// asked once the sitting has committed, names the library fields those
  /// writes changed (a site's features, its types): they write without
  /// stamping, since the stamp goes to the shared library store, which a
  /// rollback would not undo, and are stamped here instead.
  ///
  /// [privateOnly] saves a library reader's own changes (issue #4527, plan
  /// 5): the right to edit is not asked, and only the site's private notes
  /// and rating are taken from [apply], so no field of the library's site
  /// changes whatever the sitting holds. A site in no library is refused
  /// ([SiteEditRefused]): there notes and rating are the site's own.
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
    Set<String> Function()? heldLibraryFields,
    bool privateOnly = false,
  }) =>
      // Sync hears of the save once, after its stamps: the notices of the
      // writes inside it, sent as its transaction commits, are held too.
      SyncEventBus.holdNotices(() async {
        // The site as the sitting's own write left it, read inside the
        // transaction: the stamp below must not take in a write that lands
        // between the commit and a later read (a sync), as this diver's edit.
        DiveSite? written;
        final result = await writeRecordSitting<DiveSite>(
          table: 'dive_sites',
          recordId: siteId,
          changedCardIds: changedCardIds,
          // Asked first, inside the transaction: a profile that lost the
          // right to edit the site since the sitting began would have its
          // row kept to the private fields while the held writes went
          // through. Nothing is written instead.
          read: () async {
            if (!privateOnly &&
                !await _stamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
              throw SiteEditRefused(siteId);
            }
            final site = await _sites.getSiteById(siteId);
            // Notes and rating are a member's own only on a library site;
            // anywhere else they are the site's, and asked for as any field.
            if (privateOnly && site != null && !site.isLibrarySite) {
              throw SiteEditRefused(siteId);
            }
            return site;
          },
          apply: privateOnly ? (stored) => _privateOf(stored, apply) : apply,
          // A library site's stamp goes to the shared library store, which a
          // rollback would not undo: it waits for the commit, below.
          write: (_, merged) async {
            await _sites.updateSite(
              merged,
              actingDiverId: actingDiverId,
              stampLibrary: false,
            );
            written = await _sites.getSiteById(siteId);
          },
          writeFirst: writeFirst,
          alsoWrite: alsoWrite,
          alsoWriteIsAChange: alsoWriteIsAChange,
        );
        if (result == null) return null;
        // The write is committed. A stamp that fails from here on must not read
        // as a save that failed: the diver would save the sitting a second time.
        try {
          // As stored: the write keeps a reader's site to its private fields.
          await _sites.stampLibraryEdit(
            result.before,
            written ?? result.after,
            actingDiverId: actingDiverId,
          );
        } catch (error, stackTrace) {
          _log.error(
            'Library stamp after saving site $siteId failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
        await _stampHeldWrites(siteId, heldLibraryFields, actingDiverId);
        // The stamps mark the library's copy for the next sync: one notice, sent
        // as the hold ends, after them.
        SyncEventBus.notifyLocalChange();
        return result;
      });

  /// Creates [site], a new site's sitting (issue #4527, phase 2, plan 6),
  /// keeping its id: the row, then [alsoWrite], the sitting's held writes,
  /// which all point at it, in one transaction and one change log operation
  /// naming [changedCardIds]. If any of them throws nothing is left. Returns
  /// the site as stored at the end. Throws [StateError] when [site] has no
  /// id, or one a stored site already has.
  Future<DiveSite> create({
    required DiveSite site,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) {
    if (site.id.isEmpty) {
      return Future.error(
        StateError('A new site needs its id before it is created'),
      );
    }
    return runRecordSitting(
      table: 'dive_sites',
      recordId: site.id,
      changedCardIds: changedCardIds,
      body: () async {
        if (await _sites.getSiteById(site.id) != null) {
          throw StateError('Site ${site.id} already exists');
        }
        final created = await _sites.createSite(site);
        await alsoWrite?.call();
        return await _sites.getSiteById(created.id) ?? created;
      },
    );
  }

  /// [stored] with only the private notes and rating [apply] gives it.
  static DiveSite _privateOf(
    DiveSite stored,
    DiveSite Function(DiveSite stored) apply,
  ) {
    final merged = apply(stored);
    return stored.copyWith(
      notes: merged.notes,
      rating: merged.rating,
      clearRating: merged.rating == null,
    );
  }

  /// Stamps the library fields the sitting's held writes changed, once the
  /// sitting has committed. Best effort, as the row's own stamp.
  Future<void> _stampHeldWrites(
    String siteId,
    Set<String> Function()? heldLibraryFields,
    String? actingDiverId,
  ) async {
    if (heldLibraryFields == null) return;
    try {
      final fields = heldLibraryFields();
      if (fields.isEmpty) return;
      await _stamper.stamp(siteId, fields, actingDiverId: actingDiverId);
    } catch (error, stackTrace) {
      _log.error(
        'Library stamp of held writes after saving site $siteId failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
