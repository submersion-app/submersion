import 'dart:async';

/// The divers who lost a medical clearance to a delete (issue #4609).
///
/// Only a diver's current clearance reminds (#4541), so deleting it has
/// to bring back the one it superseded. Every document delete reaches
/// `DocumentRepository`'s delete step, owner deletes included, but the
/// repository is built without Riverpod in many places; it names the
/// divers here and the app's root listener re-arms them with the active
/// settings. The listener's reads run outside the delete's transaction,
/// so they see the committed rows: after a rollback they find the deleted
/// clearance back and leave it current.
class ClearanceDeleteEvents {
  ClearanceDeleteEvents._();

  static final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  static Stream<Set<String>> get stream => _controller.stream;

  static void notify(Set<String> diverIds) {
    if (diverIds.isEmpty || _controller.isClosed) return;
    _controller.add(Set.unmodifiable(diverIds));
  }
}
