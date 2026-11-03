import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';

import 'package:submersion/core/database/background_database_connection_web.dart';

/// The sqlite3.wasm drift's worker runs, loaded a second time in the page,
/// once: a backup download, a restore's note and its checks each use it,
/// each over its own in-memory file system. Drift holds its own file open
/// in a worker where the page cannot read it.
Future<WasmSqlite3>? _module;
Uri? _moduleUri;
int _nextFileSystem = 0;

Future<WasmSqlite3> _sqlite() {
  final uri = BackgroundDatabaseConnection.sqlite3Uri;
  if (_module == null || _moduleUri != uri) {
    _moduleUri = uri;
    _module = WasmSqlite3.loadFromUrl(uri).catchError((Object e) {
      // A failed load is not kept: the next use tries again.
      _module = null;
      throw e;
    });
  }
  return _module!;
}

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
