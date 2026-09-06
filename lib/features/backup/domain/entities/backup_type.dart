// lib/features/backup/domain/entities/backup_type.dart

/// Distinguishes a user-initiated (manual / automatic) backup from the two
/// kinds of copy the app takes for itself.
///
/// Persisted by name in the SharedPreferences registry, and read back by
/// `BackupRecord._parseType`, which falls back to [manual] for a name it does
/// not know. That fallback is what lets an OLDER build read a registry a
/// newer one wrote, so a value added here must stay safe to be mistaken for a
/// manual backup: [preDowngrade] records are written `pinned`, which exempts
/// them from every retention path including the manual one.
enum BackupType {
  manual,

  /// Taken automatically before a schema migration runs, holding the database
  /// exactly as the older build left it.
  preMigration,

  /// Taken when a diver goes BACK to an older build from the schema-mismatch
  /// screen: the newer-schema database that the restore is about to displace
  /// (issue #1589). Only the newer build can open it, so it is kept rather
  /// than offered, and never pruned.
  preDowngrade,
}
