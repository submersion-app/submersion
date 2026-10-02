/// Reported by the share-sheet handler when files handed to the app cannot
/// be read.
///
/// The usual cause on Android is a sending app that shares a path inside its
/// own private storage instead of a readable `content://` URI: the path
/// arrives, but the app is not allowed to open it. Such a share used to end
/// without a message or a log line (issue #2689).
///
/// Reported whether or not anything else in the share was imported;
/// [nothingReadable] tells the two apart.
class SharedFileUnreadableException implements Exception {
  /// The shared paths that could not be read, in share order.
  final List<String> unreadablePaths;

  /// How many files the share carried in all.
  final int sharedCount;

  const SharedFileUnreadableException({
    required this.unreadablePaths,
    required this.sharedCount,
  });

  /// True when no file in the share could be read, so nothing was imported.
  bool get nothingReadable => unreadablePaths.length >= sharedCount;

  /// Names every path: this is the line that reaches the debug log, and
  /// "which file, from where" is what explains the failure.
  @override
  String toString() =>
      'Could not read ${unreadablePaths.length} of $sharedCount shared '
      'file(s): ${unreadablePaths.join(', ')}';
}
