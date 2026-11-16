import 'dart:async';

/// The medical clearances a delete took, keyed by their diver (issue
/// #4609).
///
/// Only a diver's current clearance reminds (#4541), so deleting it has
/// to bring back the one it superseded. Every document delete reaches
/// `DocumentRepository`'s delete step, owner deletes included, but the
/// repository is built without Riverpod in many places; it names the
/// divers here and the app's root listener re-arms them with the active
/// settings. The listener's reads run outside the delete's transaction,
/// so they see the committed rows: after a rollback they find the deleted
/// clearance back and leave it current. The deleted ids ride along so a
/// later event can cancel a reminder an earlier one armed for a row that
/// is gone by then.
class ClearanceDeleteEvents {
  ClearanceDeleteEvents._();

  static final StreamController<Map<String, Set<String>>> _controller =
      StreamController<Map<String, Set<String>>>.broadcast();

  /// Diver id to the ids of that diver's clearances the delete took.
  static Stream<Map<String, Set<String>>> get stream => _controller.stream;

  static void notify(Map<String, Set<String>> deletedByDiver) {
    if (deletedByDiver.isEmpty || _controller.isClosed) return;
    _controller.add(
      Map.unmodifiable({
        for (final MapEntry(key: diver, value: ids) in deletedByDiver.entries)
          diver: Set<String>.unmodifiable(ids),
      }),
    );
  }
}
