// The browser's database worker.
//
// Compiled apart from the Flutter app by scripts/web/compile_workers.sh
// (`dart compile js`), so everything it reaches must be plain Dart;
// test/architecture/web_worker_import_graph_test.dart guards that. Drift
// opens SQLite (sqlite3.wasm) here, in a shared or dedicated worker, and
// registers the app's SQL functions on every connection it serves, exactly
// as the native connection setup does.
import 'package:drift/wasm.dart';

import 'package:submersion/core/database/app_sql_functions.dart';

void main() =>
    WasmDatabase.workerMainForOpen(setupAllDatabases: registerAppSqlFunctions);
