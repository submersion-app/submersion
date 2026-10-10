import 'dart:io';

import 'package:characters/characters.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';

/// Longest note a diver can attach to a backup, in user-perceived characters.
const int maxBackupNoteLength = 200;

/// Table that carries a backup's note inside the backup file itself.
///
/// It is not part of the Drift schema and exists only in backup copies: the
/// copy is stamped right after it is made, and a restore drops it from the
/// live database. The note lives in the file, not only in the history record,
/// so it survives a share, a SAF folder, a cloud upload and a reinstall.
const String backupInfoTable = 'backup_info';

const String _noteKey = 'note';

const _log = LoggerService('BackupNoteStamp');

/// Trims [note], turns a blank one into null and caps it at
/// [maxBackupNoteLength] grapheme clusters, so an emoji is never split.
String? normalizeBackupNote(String? note) {
  final trimmed = note?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final characters = trimmed.characters;
  if (characters.length <= maxBackupNoteLength) return trimmed;
  return characters.take(maxBackupNoteLength).toString().trimRight();
}

/// Writes [note] into the plaintext backup copy at [path].
///
/// Always drops the table first. A copy of a database that was itself restored
/// from a noted backup would otherwise carry that old note forward, including
/// into an automatic backup that has no note of its own.
///
/// Throws when the copy cannot be opened or written: the caller is making a
/// backup, and one that silently lacks the note the diver typed is worse than
/// a reported failure.
void stampBackupNote(String path, String? note) {
  final normalized = normalizeBackupNote(note);
  final db = DatabaseService.openRaw(path);
  try {
    db.execute('DROP TABLE IF EXISTS $backupInfoTable');
    if (normalized == null) return;
    db.execute(
      'CREATE TABLE $backupInfoTable '
      '(key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
    );
    db.execute('INSERT INTO $backupInfoTable (key, value) VALUES (?, ?)', [
      _noteKey,
      normalized,
    ]);
  } finally {
    db.close();
  }
}

/// The note stamped into the backup at [path], or null.
///
/// Null covers every file that cannot answer: missing, an encrypted `.sbe`
/// (unreadable before decryption), a SQLCipher copy, a non-database, and a
/// backup made before notes existed. Never throws, since every caller is
/// showing a file and must carry on without the note.
Future<String?> readBackupNote(String path) async {
  try {
    if (!await File(path).exists()) return null;
    if (await BackupCrypto.isEncryptedBackup(path)) return null;
    final db = DatabaseService.openRaw(path, mode: sqlite3.OpenMode.readOnly);
    try {
      final table = db.select(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        [backupInfoTable],
      );
      if (table.isEmpty) return null;
      final rows = db.select(
        'SELECT value FROM $backupInfoTable WHERE key = ?',
        [_noteKey],
      );
      if (rows.isEmpty) return null;
      return normalizeBackupNote(rows.first['value'] as String?);
    } finally {
      db.close();
    }
  } catch (_) {
    return null;
  }
}

/// Makes a backup copy at [path] with [export], then stamps [note] into it.
///
/// With no note the stamp is only hygiene (dropping a table inherited from a
/// restored backup), so a failure is logged and the copy kept. That matters:
/// `DatabaseService.backup` falls back to a raw byte copy exactly when the
/// live file will not open, SQLite cannot open that copy either, and it may be
/// the only copy of whatever survives. With a note the stamp is what the diver
/// asked for, so a failure fails the backup.
Future<void> exportAndStampBackup(
  String path, {
  required Future<void> Function(String path) export,
  String? note,
}) async {
  await export(path);
  if (normalizeBackupNote(note) != null) {
    stampBackupNote(path, note);
    return;
  }
  try {
    stampBackupNote(path, null);
  } catch (e, st) {
    _log.warning(
      'Kept a backup copy whose inherited note could not be cleared',
      error: e,
      stackTrace: st,
    );
  }
}
