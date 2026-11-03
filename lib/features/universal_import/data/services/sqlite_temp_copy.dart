import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart';

import 'package:submersion/core/platform/sqlite/raw_sqlite.dart';

/// Writes [bytes] into a private temp directory, opens the copy read-only,
/// runs [body], and always removes the directory.
///
/// The directory comes from `createTemp`, which the OS guarantees to be
/// unique. A timestamp-derived name does not: two calls landing in the same
/// millisecond (or microsecond) would share a path, and each would delete or
/// overwrite the file the other was still reading. [prefix] only makes the
/// directory recognisable in the temp folder.
///
/// [body] must be synchronous: the database is closed and the copy deleted as
/// soon as it returns.
Future<T> withTempSqliteCopy<T>(
  Uint8List bytes, {
  required String prefix,
  required T Function(CommonDatabase db) body,
}) async {
  final tmpDir = await Directory.systemTemp.createTemp(prefix);
  try {
    final tmpFile = File(p.join(tmpDir.path, 'import.sqlite'));
    await tmpFile.writeAsBytes(bytes);
    final db = RawSqlite.open(tmpFile.path, mode: OpenMode.readOnly);
    try {
      final result = body(db);
      assert(result is! Future, 'body must not be async; the db closes first');
      return result;
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
