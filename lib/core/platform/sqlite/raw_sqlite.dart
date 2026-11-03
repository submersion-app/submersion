/// Direct access to a SQLite database handle outside drift.
///
/// The native app opens files and in-memory probes through the FFI build of
/// `package:sqlite3`; the browser has no such build, so the web file reports
/// the facility unavailable and every open throws. Callers that must work on
/// both platforms check [RawSqlite.isAvailable] first or route the work
/// through drift instead.
library;

export 'package:submersion/core/platform/sqlite/raw_sqlite_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/sqlite/raw_sqlite_web.dart';
