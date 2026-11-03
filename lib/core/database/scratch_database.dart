/// A throwaway SQLite database that gives its bytes back once it has been
/// filled (issue #4121): the browser's backup copy is built in one, and the
/// native engine builds the same copy for the tests that prove it.
///
/// Natively it is a file in a temporary folder that goes when the bytes
/// have been read; in a browser it lives in the page's memory on a second
/// copy of sqlite3.wasm, since a page cannot read drift's own file.
library;

export 'package:submersion/core/database/scratch_database_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/database/scratch_database_web.dart';
