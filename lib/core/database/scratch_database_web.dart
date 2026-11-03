import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';

import 'package:submersion/core/database/background_database_connection_web.dart';
import 'package:submersion/core/utils/keyed_load_cache.dart';

/// The sqlite3.wasm drift's worker runs, loaded a second time in the page,
/// once per asset URI: a backup download, a restore's note and its checks
/// each use it, each over its own in-memory file system. Drift holds its own
/// file open in a worker where the page cannot read it.
final _module = KeyedLoadCache<Uri, WasmSqlite3>(WasmSqlite3.loadFromUrl);
int _nextFileSystem = 0;

Future<WasmSqlite3> _sqlite() =>
    _module.get(BackgroundDatabaseConnection.sqlite3Uri);

/// Runs [use] with [files] registered under a name of its own, and takes
/// it away again afterwards.
Future<T> _withFileSystem<T>(
  InMemoryFileSystem files,
  Future<T> Function(WasmSqlite3 sqlite) use,
) async {
  final sqlite = await _sqlite();
  sqlite.registerVirtualFileSystem(files);
  try {
    return await use(sqlite);
  } finally {
    sqlite.unregisterVirtualFileSystem(files);
  }
}

InMemoryFileSystem _newFileSystem() =>
    InMemoryFileSystem(name: 'submersion-scratch-${_nextFileSystem++}');

/// Builds a database in the page's memory with [fill] and returns its bytes.
Future<Uint8List> withScratchDatabase(
  Future<void> Function(CommonDatabase scratch) fill,
) async {
  const path = '/image.db';
  final files = _newFileSystem();
  return _withFileSystem(files, (sqlite) async {
    final scratch = sqlite.open(path, vfs: files.name);
    try {
      await fill(scratch);
    } finally {
      scratch.close();
    }
    // Copied out of the buffer the file system owns, which the memory VFS
    // may have grown past the file's length.
    return Uint8List.fromList(files.fileData[path]!);
  });
}

/// Opens [image], the bytes of a SQLite file, from the page's memory and
/// returns what [read] makes of it.
Future<T> readScratchImage<T>(
  Uint8List image,
  T Function(CommonDatabase db) read,
) async {
  const path = '/image.db';
  final files = _newFileSystem();
  files
      .xOpen(
        Sqlite3Filename(path),
        SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
      )
      .file
    ..xWrite(image, 0)
    ..xClose();
  return _withFileSystem(files, (sqlite) async {
    final db = sqlite.open(path, vfs: files.name, mode: OpenMode.readOnly);
    try {
      return read(db);
    } finally {
      db.close();
    }
  });
}
