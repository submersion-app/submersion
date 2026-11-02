import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';

import 'package:submersion/core/database/background_database_connection_web.dart';

/// Builds a database in the page's memory with [fill] and returns its bytes.
///
/// The sqlite3.wasm drift's worker runs is loaded a second time here, in
/// the page, over an in-memory file system: drift holds its own file open
/// in a worker where the page cannot read it.
Future<Uint8List> withScratchDatabase(
  Future<void> Function(CommonDatabase scratch) fill,
) async {
  const path = '/image.db';
  final sqlite = await WasmSqlite3.loadFromUrl(
    BackgroundDatabaseConnection.sqlite3Uri,
  );
  final files = InMemoryFileSystem();
  sqlite.registerVirtualFileSystem(files, makeDefault: true);
  final scratch = sqlite.open(path);
  try {
    await fill(scratch);
  } finally {
    scratch.close();
  }
  // Copied out of the buffer the file system owns, which the memory VFS
  // may have grown past the file's length.
  return Uint8List.fromList(files.fileData[path]!);
}
