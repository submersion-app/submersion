part of 'dive_detail_page.dart';

/// The dive page's whole-record operations (issue #4527): delete, re-parse,
/// mark as logged and the rest. Each acts on the dive at once and is its
/// own History entry, so on a page that offers editing it runs only while
/// the page is unlocked with nothing to save, and the sitting then starts
/// again from the dive as stored ([RecordEditController.runOperation]).
mixin _DiveDetailPageOperations
    on
        ConsumerState<DiveDetailPage>,
        _DiveDetailPageActions,
        _DiveDetailPageEditing {
  /// Whether the operations may run now.
  RecordOperationBlock get operationBlock =>
      recordOperationBlockOf(editController)!;

  /// Runs [operation], which answers whether it wrote. A page that offers
  /// editing runs it through its controller, which refuses while locked or
  /// with unsaved changes; the controls that start one say so beforehand.
  ///
  /// Every caller drops the returned Future, so a failure is logged, never
  /// thrown ([recordOperationRunnerOf], which the cards' controls use too):
  /// the operation's own message has told the diver, and the page carries
  /// on as the controller left it.
  Future<void> _runOperation(Future<bool> Function() operation) =>
      recordOperationRunnerOf(editController, record: 'dive $diveId')(
        operation,
      );

  /// Delete, from the menu: asks, deletes, then leaves the page. A sitting
  /// ends first, as the dive it was opened on is gone.
  Future<void> _deleteDive() async {
    var deleted = false;
    await _runOperation(() async => deleted = await _confirmAndDelete());
    if (deleted) _leaveDeletedDive();
  }

  /// Edit profile, from the Profile card: the editor saves on its own page.
  Future<bool> _editProfile() async =>
      (await openProfileEditor(context, ref, diveId)).saved;

  /// The profile's outliers, from the Profile card: the editor opened in
  /// Outlier mode.
  Future<bool> _editOutliers() async => (await openProfileEditor(
    context,
    ref,
    diveId,
    initialMode: 'outlier',
  )).saved;

  /// Draw a profile, from the menu, for a dive that has none.
  Future<bool> _drawProfile() async => (await openProfileEditor(
    context,
    ref,
    diveId,
    initialMode: 'draw',
  )).saved;
}
