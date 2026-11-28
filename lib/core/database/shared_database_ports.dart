/// Lets a desktop pop-out window's engine use the database workers the main
/// window opened (issue #5078).
///
/// The main window publishes each worker's connect port under a fixed name;
/// a pop-out looks the name up and connects as a second client, so it never
/// opens the database file itself. Browsers have no second engine, so the web
/// half publishes nothing and finds nothing.
library;

export 'package:submersion/core/database/shared_database_ports_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/database/shared_database_ports_web.dart';
