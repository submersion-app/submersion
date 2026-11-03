import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as ffi;

/// Native implementation of the raw SQLite facade: the FFI build of
/// `package:sqlite3`, which on this app is a SQLCipher build.
abstract final class RawSqlite {
  /// Always true on a native build: the library is linked into the binary.
  static bool get isAvailable => true;

  /// Opens the database file at [path] with [mode], creating it when the
  /// mode allows, exactly as `sqlite3.open` does.
  static CommonDatabase open(
    String path, {
    OpenMode mode = OpenMode.readWriteCreate,
  }) => ffi.sqlite3.open(path, mode: mode);

  /// Opens a throwaway in-memory database.
  static CommonDatabase openInMemory() => ffi.sqlite3.openInMemory();
}
