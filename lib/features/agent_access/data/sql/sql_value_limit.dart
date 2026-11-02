import 'dart:ffi';

import 'package:sqlite3/sqlite3.dart' show Database;

/// `SQLITE_LIMIT_LENGTH`.
const int _limitLength = 0;

/// `package:sqlite3` binds most of the C API but not this function, so it is
/// bound here against the same native asset.
@Native<Int Function(Pointer<Void>, Int, Int)>(
  symbol: 'sqlite3_limit',
  assetId: 'package:sqlite3/src/ffi/libsqlite3.g.dart',
)
external int _sqlite3Limit(Pointer<Void> db, int id, int newValue);

/// Stops [db] building or reading any string or blob over [bytes].
///
/// SQLite assembles a value inside its own step, so a check on the Dart side
/// sees `printf('%.*c', 1000000000, 'x')` only once the gigabyte exists. This
/// limit fails the statement with "string or blob too big" instead. It belongs
/// to this connection alone, unlike `hard_heap_limit`, which is process-wide
/// and would reach the app's own connection.
///
/// A resource limit, not a security one. A library that does not export the
/// symbol raises [ArgumentError] here, and the window then runs as it would
/// without the limit rather than losing the tool.
void limitSqlValueSize(Database db, int bytes) {
  try {
    _sqlite3Limit(db.handle.cast(), _limitLength, bytes);
  } on ArgumentError {
    return;
  }
}
