import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Saves one editing sitting on a site (issue #4527, phase 2).
///
/// The diver's changes are applied to the site as it is stored at the
/// moment of saving, not as it was when the sitting began, so a value
/// changed underneath meanwhile (a sync) on a card the diver never touched
/// is not written back over. Everything is written in one database
/// transaction and one change log operation ([writeRecordSitting]), so the
/// sitting is one History entry that reverts as a unit.
class SiteEditSaveService {
  SiteEditSaveService(this._sites);

  final SiteRepository _sites;
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
  /// held writes, as [writeRecordSitting] runs them.
  Future<({DiveSite before, DiveSite after})?> save({
    required String siteId,
    required DiveSite Function(DiveSite stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
    Future<void> Function()? writeFirst,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    // The site as the sitting's own write left it, read inside the
    // transaction: the stamp below must not take in a write that lands
    // between the commit and a later read (a sync), as this diver's edit.
    DiveSite? written;
    final result = await writeRecordSitting<DiveSite>(
      table: 'dive_sites',
      recordId: siteId,
      changedCardIds: changedCardIds,
      read: () => _sites.getSiteById(siteId),
      apply: apply,
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
    return result;
  }
}
