/// The drift connection the app's databases run on, and the shutdown helper
/// that waits for SQLite to finish closing.
///
/// On a native build the work runs on a background isolate this module owns
/// (`background_database_connection_io.dart`). In a browser the database
/// lives behind a drift web worker instead; that implementation arrives with
/// the browser database work, and until then the web file throws.
library;

export 'package:submersion/core/database/background_database_connection_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/database/background_database_connection_web.dart';
