import 'dart:isolate';

import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_io.dart';

/// Top level, so the closure it hands to the isolate captures only [request].
Future<SqlWindowOutcome> runSqlWindowOnWorker(SqlWindowRequest request) =>
    Isolate.run(() => runSqlWindow(request));
