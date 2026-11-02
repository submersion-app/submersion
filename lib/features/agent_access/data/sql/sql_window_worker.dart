/// Where a statement runs: on a worker isolate natively; a browser never
/// runs one, since it cannot bind the agent listener (issue #4121).
library;

export 'sql_window_worker_io.dart'
    if (dart.library.js_interop) 'sql_window_worker_web.dart';
