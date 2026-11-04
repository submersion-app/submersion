import 'dart:convert';
import 'dart:typed_data';

/// Reading and adjusting the 100-byte header of a SQLite database held in
/// memory: a backup file the browser read through its picker, or the sample
/// logbook it fetched (issue #4121). See https://sqlite.org/fileformat.html.

const int _headerLength = 100;
final Uint8List _magic = ascii.encode('SQLite format 3\u0000');

/// Offsets of the file format write and read versions: 1 for a rollback
/// journal, 2 for WAL.
const int _writeVersionOffset = 18;
const int _readVersionOffset = 19;
const int _walVersion = 2;
const int _rollbackVersion = 1;

/// Offset of `PRAGMA user_version`, which drift keeps the schema in.
const int _userVersionOffset = 60;

/// Whether [bytes] starts with a SQLite database header.
bool isSqliteImage(Uint8List bytes) {
  if (bytes.length < _headerLength) return false;
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return false;
  }
  return true;
}

/// The schema version stored in the header of [bytes], a SQLite image.
int sqliteImageUserVersion(Uint8List bytes) =>
    ByteData.sublistView(bytes).getUint32(_userVersionOffset);

/// [bytes] with its header set to a rollback journal, as a copy when it
/// said WAL and as itself otherwise.
///
/// A database copied from a WAL-mode file keeps the WAL flag, and a browser
/// file system has no shared memory to open one with. A backup is a single
/// complete file with no `-wal` beside it, so the flag is all that changes.
Uint8List withRollbackJournal(Uint8List bytes) {
  if (bytes[_writeVersionOffset] != _walVersion &&
      bytes[_readVersionOffset] != _walVersion) {
    return bytes;
  }
  return Uint8List.fromList(bytes)
    ..[_writeVersionOffset] = _rollbackVersion
    ..[_readVersionOffset] = _rollbackVersion;
}
