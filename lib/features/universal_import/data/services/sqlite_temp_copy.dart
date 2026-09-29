import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Writes [bytes] into a private temp directory, opens the copy read-only,
/// runs [body], and always removes the directory.
///
/// The directory comes from `createTemp`, which the OS guarantees to be
/// unique. A timestamp-derived name does not: two calls landing in the same
/// millisecond (or microsecond) would share a path, and each would delete or
/// overwrite the file the other was still reading. [prefix] only makes the
/// directory recognisable in the temp folder.
Future<T> withTempSqliteCopy<T>(
  Uint8List bytes, {
  required String prefix,
  required T Function(Database db) body,
}) async {
  final tmpDir = await Directory.systemTemp.createTemp(prefix);
  try {
    final tmpFile = File(p.join(tmpDir.path, 'import.sqlite'));
    await tmpFile.writeAsBytes(bytes);
    final db = sqlite3.open(tmpFile.path, mode: OpenMode.readOnly);
    try {
      return body(db);
    } finally {
      db.close();
    }
  } finally {
    _deleteTempDir(tmpDir);
  }
}

void _deleteTempDir(Directory dir) {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {
    // Best-effort cleanup.
  }
}
