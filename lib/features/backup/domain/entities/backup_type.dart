// lib/features/backup/domain/entities/backup_type.dart

/// Distinguishes a user-initiated (manual / automatic) backup from a
/// system-initiated backup taken before a schema migration runs.
enum BackupType { manual, preMigration }
