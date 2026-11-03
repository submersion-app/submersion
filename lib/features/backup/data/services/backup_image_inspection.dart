import 'dart:typed_data';

import 'package:submersion/core/database/database_image_header.dart';
import 'package:submersion/core/database/scratch_database.dart';
import 'package:submersion/features/backup/data/services/backup_crypto_image.dart';
import 'package:submersion/features/backup/data/services/backup_note_stamp.dart';

/// What a browser restore learns about a backup held in memory before it
/// swaps it in (issue #4121), from the same queries the native restore runs
/// on a file.
class BackupImageInfo {
  const BackupImageInfo({
    required this.hasSubmersionTables,
    required this.schemaVersion,
    this.note,
  });

  /// Whether the database holds Submersion's dive tables.
  final bool hasSubmersionTables;

  /// The schema it was written at (`PRAGMA user_version`).
  final int schemaVersion;

  /// The note stamped into it, if any.
  final String? note;
}

/// Reads [image], the bytes of a plaintext backup, read-only. Throws when
/// the bytes do not open as a SQLite database.
Future<BackupImageInfo> inspectBackupImage(Uint8List image) =>
    readScratchImage(withRollbackJournal(image), (db) {
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name IN ('dives', 'dive_sites')",
      );
      final version = db.select('PRAGMA user_version').first.values.first;
      return BackupImageInfo(
        hasSubmersionTables: tables.isNotEmpty,
        schemaVersion: version as int,
        note: readBackupNoteFrom(db),
      );
    });

/// The note of a plaintext backup held in memory, for the confirmation
/// dialog; null for an encrypted or unreadable one. Never throws.
Future<String?> readBackupNoteFromImage(Uint8List bytes) async {
  if (BackupCryptoImage.isEncrypted(bytes) || !isSqliteImage(bytes)) {
    return null;
  }
  try {
    return (await inspectBackupImage(bytes)).note;
  } catch (_) {
    return null;
  }
}
