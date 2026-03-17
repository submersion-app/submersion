/// Thrown when the database file was created by a newer version of
/// Submersion than the currently running app.
///
/// This prevents an older app from silently corrupting a newer schema
/// by running stale migrations or downgrading the version stamp.
class DatabaseVersionMismatchException implements Exception {
  final int databaseVersion;
  final int appVersion;

  const DatabaseVersionMismatchException({
    required this.databaseVersion,
    required this.appVersion,
  });

  @override
  String toString() =>
      'DatabaseVersionMismatchException: database is schema v$databaseVersion '
      'but this app only supports up to v$appVersion. '
      'Please update Submersion to the latest version.';
}
