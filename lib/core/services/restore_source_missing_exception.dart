/// Thrown by `DatabaseService.restore` when the backup it was asked to swap
/// in does not exist at [backupPath].
///
/// The live database is left exactly as it was: the swap never starts, so no
/// "database unavailable" window opens and no data changes. That is the right
/// thing to do with the data, but it must not pass for a completed restore.
/// A user recovering from data loss cannot tell a restore that did nothing
/// apart from a restore of an empty library, and the two have very different
/// root causes (issue #1344). Callers surface this as "nothing was restored",
/// never as "Restore Complete".
class RestoreSourceMissingException implements Exception {
  /// The path the restore was pointed at; the file was absent by the time
  /// the swap ran (a download that produced no bytes, a temp directory reaped
  /// between materialization and use, a swallowed upstream error).
  final String backupPath;

  const RestoreSourceMissingException(this.backupPath);

  /// Written to be shown as-is. The backup flow maps this exception to a
  /// localized message, but the startup recovery restore and the settings
  /// export restore render `'$e'` unlocalized, so the text is a sentence
  /// rather than a class name. It names the file because at those two call
  /// sites the path is the user's own pick or the app's recovery backup, and
  /// "which file" is the one detail that helps.
  @override
  String toString() =>
      'Nothing was restored: the backup file could not be found at '
      '$backupPath';
}
