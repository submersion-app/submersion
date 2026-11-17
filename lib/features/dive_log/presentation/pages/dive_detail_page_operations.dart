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
  /// Whether the operations may run now, or null when the page offers no
  /// editing and they act as they always have.
  RecordOperationBlock? get operationBlock =>
      editingOffered ? recordOperationBlockOf(editController) : null;

  /// Runs [operation], which answers whether it wrote. A page that offers
  /// editing runs it through its controller, which refuses while locked or
  /// with unsaved changes; the controls that start one say so beforehand.
  Future<void> _runOperation(Future<bool> Function() operation) async {
    if (!editingOffered) {
      await operation();
      return;
    }
    await editController.runOperation(operation);
  }

  /// Delete, from the menu: asks, deletes, then leaves the page. A sitting
  /// ends first, as the dive it was opened on is gone.
  Future<void> _deleteDive() async {
    var deleted = false;
    await _runOperation(() async => deleted = await _confirmAndDelete());
    if (deleted) _leaveDeletedDive();
  }
}
