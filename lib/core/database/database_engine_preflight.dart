import 'package:sqlite3/common.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/platform/sqlite/raw_sqlite.dart';

/// Thrown when the SQLite/SQLCipher engine the app is linked against cannot be
/// used at all: the native library is missing or unresolvable, or it loaded
/// but is not a SQLCipher build.
///
/// The defining property is that no user file has been touched. Every other
/// startup database failure happens *to* the diver's database; this one
/// happens before it is ever opened, so the honest report is "this build is
/// broken", not "your data is damaged". Issue #1129 shipped a Windows build
/// without `sqlcipher.dll` and the app reported it as a failed upgrade.
class DatabaseEngineUnavailableException implements Exception {
  const DatabaseEngineUnavailableException(this.reason, {this.cause});

  /// User-independent explanation of what is wrong with the build.
  final String reason;

  /// The underlying error, when there was one. Kept for the technical-details
  /// line on the startup failure screen and for the log.
  final Object? cause;

  @override
  String toString() {
    final suffix = cause == null ? '' : ' ($cause)';
    return 'DatabaseEngineUnavailableException: $reason$suffix';
  }
}

/// The two operations [assertDatabaseEngineAvailable] needs from a throwaway
/// database handle.
///
/// Deliberately narrower than [CommonDatabase]: a test can implement it
/// without a `noSuchMethod` stand-in for the whole engine API, and the seam
/// still covers the failure that matters (the open itself throwing).
abstract interface class DatabaseEngineProbe {
  /// The rows `PRAGMA cipher_version` answers. Empty on a vanilla SQLite
  /// build; a version string on a SQLCipher one.
  List<String> readCipherVersion();

  void close();
}

/// Opens the throwaway probe. Injectable so tests can simulate a build whose
/// native library does not resolve.
typedef DatabaseEngineProbeOpener = DatabaseEngineProbe Function();

class _InMemoryEngineProbe implements DatabaseEngineProbe {
  _InMemoryEngineProbe() : _db = RawSqlite.openInMemory();

  final CommonDatabase _db;

  @override
  List<String> readCipherVersion() => [
    for (final row in _db.select('PRAGMA cipher_version'))
      '${row.values.first}',
  ];

  @override
  void close() => _db.close();
}

/// Verifies the database engine works before anything touches the diver's
/// database file.
///
/// Opens an in-memory database and reads `PRAGMA cipher_version`, the same
/// invariant `test/core/database/sqlcipher_setup_test.dart` asserts at build
/// time. Checking it here at runtime means a build that fails it in the field
/// says so precisely instead of being misattributed to whatever step happened
/// to be running.
///
/// In-memory on purpose: it exercises library loading, `sqlite3_initialize`
/// and the SQLCipher extension without opening, locking or creating any file,
/// so a failure here provably leaves the diver's data untouched.
///
/// Throws [DatabaseEngineUnavailableException]; returns normally otherwise.
void assertDatabaseEngineAvailable({DatabaseEngineProbeOpener? openProbe}) {
  // A browser has no in-memory handle to probe: sqlite3.wasm loads when the
  // database opens, and a failure there is reported as this same exception
  // by the web connection, so the failure screen still says "this build is
  // broken" rather than "your data is damaged".
  if (HostPlatform.isWeb && openProbe == null) return;
  final DatabaseEngineProbe probe;
  try {
    probe = (openProbe ?? _InMemoryEngineProbe.new)();
  } catch (e) {
    throw DatabaseEngineUnavailableException(
      'The SQLite native library could not be loaded.',
      cause: e,
    );
  }

  try {
    final List<String> cipherVersion;
    try {
      cipherVersion = probe.readCipherVersion();
    } catch (e) {
      throw DatabaseEngineUnavailableException(
        'The database engine failed its startup self-check.',
        cause: e,
      );
    }
    if (cipherVersion.isEmpty) {
      throw const DatabaseEngineUnavailableException(
        'The linked SQLite library is not a SQLCipher build, so no '
        'database can be opened.',
      );
    }
  } finally {
    // Housekeeping on a throwaway in-memory handle. A failure here must not
    // turn a healthy engine into a terminal startup error; that would be the
    // same class of misdiagnosis this preflight exists to prevent.
    try {
      probe.close();
    } catch (_) {}
  }
}
