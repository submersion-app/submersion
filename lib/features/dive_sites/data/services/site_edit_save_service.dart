import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
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

  /// Applies [apply] to the site as stored now and writes the result
  /// through [SiteRepository.updateSite], for [actingDiverId], so a library
  /// site is stamped and its private fields kept as they are from any
  /// other save.
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
  }) => writeRecordSitting<DiveSite>(
    table: 'dive_sites',
    recordId: siteId,
    changedCardIds: changedCardIds,
    read: () => _sites.getSiteById(siteId),
    apply: apply,
    write: (_, merged) =>
        _sites.updateSite(merged, actingDiverId: actingDiverId),
    writeFirst: writeFirst,
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWriteIsAChange,
  );
}
