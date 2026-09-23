/// Why the media transfer drain stopped with work left behind.
enum MediaTransferHoldKind {
  /// No network. Quiet: the queue says it is waiting for a connection and
  /// does not report a suspension, because nothing is wrong with the store.
  offline,

  /// Online, but the store could not be checked (the marker read threw or
  /// timed out). Suspends with the error, retried on the preflight window.
  storeUnreachable,

  /// This device is no longer attached to the store the worker was built
  /// for.
  detached,

  /// The store no longer carries the marker this device attached to: wiped
  /// and re-minted, or repointed. Needs the user to reconnect.
  markerMismatch,
}

/// The one reason the drain is holding, recorded by the worker and read by
/// the transfer summary (media sync program spec 7.1: the queue never waits
/// silently).
class MediaTransferHold {
  const MediaTransferHold(this.kind, this.message);

  final MediaTransferHoldKind kind;

  /// Diagnostic English, shown raw the way row errors are: the surfaces
  /// localize by [kind] and show this beneath.
  final String message;

  /// Whether this hold is a suspension the user is told about. Offline is
  /// not: an ordinary moment without network must not read as a broken
  /// store.
  bool get suspends => kind != MediaTransferHoldKind.offline;

  @override
  bool operator ==(Object other) =>
      other is MediaTransferHold &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'MediaTransferHold($kind, $message)';
}
