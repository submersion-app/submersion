/// The database file is encrypted and could not be opened: either no key was
/// available ([wrongKey] false — prompt for the password) or a key was tried
/// and rejected ([wrongKey] true — the password/cached key is wrong).
///
/// Startup routes this to the unlock screen; it must never surface as the
/// generic startup-error state.
class DatabaseLockedException implements Exception {
  final String dbPath;
  final bool wrongKey;

  const DatabaseLockedException(this.dbPath, {this.wrongKey = false});

  @override
  String toString() => 'DatabaseLockedException($dbPath, wrongKey: $wrongKey)';
}
