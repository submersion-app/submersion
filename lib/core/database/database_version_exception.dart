import 'package:submersion/core/database/database_provenance.dart';

/// Thrown when a caller that is not allowed to upgrade the schema opens a
/// database whose stored version is behind the app's.
///
/// The only such caller is a headless isolate (the Workmanager background
/// task). Running the upgrade ladder there is wrong twice over: it would race
/// the foreground launch that is almost certainly running the same ladder
/// against the same file, and it would do so with no progress UI, no
/// pre-migration safety copy, and no way to report a failure to the diver.
/// Skipping is always safe -- the task simply runs after the next foreground
/// launch has upgraded the file.
class SchemaUpgradePendingException implements Exception {
  final int storedSchemaVersion;
  final int supportedSchemaVersion;

  const SchemaUpgradePendingException({
    required this.storedSchemaVersion,
    required this.supportedSchemaVersion,
  });

  @override
  String toString() =>
      'SchemaUpgradePendingException: database is schema '
      'v$storedSchemaVersion and this app expects v$supportedSchemaVersion, '
      'but this caller may not run the upgrade ladder.';
}

/// Thrown when the database file was created by a newer version of
/// Submersion than the currently running app.
///
/// This prevents an older app from silently corrupting a newer schema
/// by running stale migrations or downgrading the version stamp.
///
/// Both fields are Drift SCHEMA versions (the `user_version` ladder), not
/// app release versions; the names say so because the older
/// `databaseVersion`/`appVersion` pair read as a marketing version and
/// invited that misreading.
class DatabaseVersionMismatchException implements Exception {
  final int storedSchemaVersion;
  final int supportedSchemaVersion;

  /// What the file says about the build that wrote it (issue #1593), or null
  /// when it says nothing: every database written before schema v194 predates
  /// the provenance table, which is exactly the population stranded by #1568.
  ///
  /// This is the difference between "you must be behind, go and get the
  /// latest stable build" (a guess, and the wrong one when the file came off
  /// the beta train) and naming the build that actually wrote the file.
  final DatabaseProvenanceRecord? provenance;

  const DatabaseVersionMismatchException({
    required this.storedSchemaVersion,
    required this.supportedSchemaVersion,
    this.provenance,
  });

  @override
  String toString() =>
      'DatabaseVersionMismatchException: database is schema '
      'v$storedSchemaVersion but this app only supports up to '
      'v$supportedSchemaVersion. Please update Submersion to the latest '
      'version.';
}
