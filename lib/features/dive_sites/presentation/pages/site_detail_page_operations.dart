part of 'site_detail_page.dart';

/// The menu entries that act on the whole site at once: delete, remove from
/// profile, unhide, add to library, delete from library.
const Set<String> kSiteRecordActions = {
  'delete',
  'remove',
  'unhide',
  'addToLibrary',
  'libraryDelete',
};

/// Who may do what to the site, read in `build` for the menus, which build
/// their entries later, where only a read sees the current value.
typedef _SiteOwnership = ({bool? canDestroy, bool hidden, bool reachesHere});

/// The site page's whole-record operations (issue #4527, phase 2): delete,
/// remove from profile, unhide and the library actions. Each acts on the
/// site at once and is its own History entry, so on a page that offers
/// editing it runs only while the site is unlocked with nothing to save,
/// and the sitting then starts again from the site as stored
/// ([RecordEditController.runOperation]); a library reader's page waits
/// for the unlock too (plan 5, Question 3). A page that offers no editing
/// (a profile that may neither edit nor suggest) runs them as it always
/// has.
mixin _SiteDetailPageOperations
    on
        ConsumerState<_SiteDetailContent>,
        RecordEditHost<_SiteDetailContent, DiveSite>,
        _SiteDetailPageEditing {
  /// Whether the operations go through the sitting: while the page offers
  /// editing, and while a sitting stays open after it stopped (a role
  /// reload that failed, a withdrawal still waiting on a save or the end
  /// of the frame), so they never write beside held changes.
  bool get _operationsThroughSitting => _offersEditingNow() || isSittingOpen;

  /// Whether the operations may run now; null where the page offers no
  /// editing and holds no sitting.
  RecordOperationBlock? get siteOperationBlock =>
      recordOperationBlockOf(_operationsThroughSitting ? editController : null);

  /// Runs [operation], which answers whether it wrote: through the sitting
  /// while the page offers editing or holds one, which refuses while locked
  /// or with unsaved changes (the menu says so beforehand), else at once.
  Future<void> _runSiteOperation(Future<bool> Function() operation) async {
    if (!_operationsThroughSitting) {
      await operation();
      return;
    }
    await recordOperationRunnerOf(
      editController,
      record: 'site ${widget.siteId}',
    )(operation);
  }

  /// Who may delete, unhide or remove the site. Call from `build`.
  _SiteOwnership _watchOwnership(WidgetRef ref, DiveSite site) {
    // Watched, as the trip page does, so the menu follows the profile once
    // it has loaded (issue #2594); null until then (issue #2682).
    final canDestroy = canDestroySharedItemOnceKnown(
      ref.watch(validatedCurrentDiverIdProvider),
      ownerId: site.diverId,
      isLibrarySite: site.isLibrarySite,
    );
    return (
      canDestroy: canDestroy,
      // A site this profile already removed offers Unhide (issue #2679).
      hidden: watchHiddenHere(
        ref,
        SharedItemKind.site,
        site.id,
        canDestroy: canDestroy != false,
      ),
      // Remove only while the site reaches this profile (issue #2151).
      reachesHere: watchReachesHere(
        ref,
        SharedItemKind.site,
        site.id,
        libraryId: site.sharedLibraryId,
      ),
    );
  }
}
