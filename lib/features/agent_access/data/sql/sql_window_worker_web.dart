import 'package:submersion/features/agent_access/data/sql/sql_window.dart';

/// Browser half: a page cannot bind the agent listener, so no tool call
/// reaches here, and SQLite's read-only window has no web build.
Future<SqlWindowOutcome> runSqlWindowOnWorker(SqlWindowRequest request) =>
    throw UnsupportedError('SQL windows do not run in a browser');
