/// Preference writes made one at a time, in the order they were asked for.
///
/// A setting does not await its change, so two quick changes can have
/// writes out together, and where a write replaces the whole preferences
/// file (Windows, Linux) two in flight can land in either order. Queued
/// here, the stored value is always the last one shown. A failed write
/// does not hold up the ones after it; its caller still sees the error.
mixin SerialPreferenceWrites {
  /// The latest write, which the next one waits on.
  Future<void> _lastWrite = Future<void>.value();

  /// Runs [write] once every write asked for before it has finished.
  Future<void> writeInTurn(Future<bool> Function() write) {
    final next = _lastWrite.then((_) => write());
    _lastWrite = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}
