import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/crypto/keyslots.dart';

/// The 16-byte magic that begins every plaintext SQLite database.
const List<int> _sqliteHeader = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, // 'SQLite f'
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00, // 'ormat 3\0'
];

/// True iff [path] exists and does NOT start with the plaintext SQLite
/// header — i.e. the file is (presumed) SQLCipher-encrypted. The file
/// header is the source of truth for encryption state; prefs flags are
/// cross-checked against it and the file wins.
bool isEncryptedDatabaseFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final raf = file.openSync();
  try {
    final header = raf.readSync(16);
    if (header.length < 16) return false;
    for (var i = 0; i < 16; i++) {
      if (header[i] != _sqliteHeader[i]) return true;
    }
    return false;
  } finally {
    raf.closeSync();
  }
}

/// The keyslot sidecar next to the database — the durable wrapped copy of
/// the Master Key (like a LUKS header). Readable before any DB open; it
/// travels with the database in set-aside, storage-move, and safety-copy
/// flows.
abstract final class DatabaseSecuritySidecar {
  static const String fileName = 'submersion.keys';

  static String pathFor(String dbPath) => p.join(p.dirname(dbPath), fileName);

  /// Whether this install has security material for [dbPath].
  ///
  /// This is the corroboration signal for an unreadable database file: a
  /// corrupt plaintext database and an encrypted one are indistinguishable at
  /// the header, so [isEncryptedDatabaseFile] alone must never decide. Both
  /// the startup gate and the schema probe consult this before concluding
  /// "encrypted" rather than "corrupt".
  static bool existsFor(String dbPath) => File(pathFor(dbPath)).existsSync();

  static Future<KeyslotFile?> read(String dbPath) async {
    final file = File(pathFor(dbPath));
    if (!await file.exists()) return null;
    return KeyslotFile.fromJsonBytes(await file.readAsBytes());
  }

  static Future<void> write(String dbPath, KeyslotFile keyslots) async {
    await File(pathFor(dbPath)).writeAsBytes(keyslots.toJsonBytes());
  }

  static Future<void> delete(String dbPath) async {
    final file = File(pathFor(dbPath));
    if (await file.exists()) await file.delete();
  }
}
