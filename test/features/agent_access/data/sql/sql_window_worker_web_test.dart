import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_worker_web.dart';

/// A browser cannot bind the agent listener, so nothing can ask it for a
/// statement (issue #4121); the web half says so if anything ever does,
/// rather than answering with an empty result.
void main() {
  test('the browser refuses to run a statement', () {
    expect(
      () => runSqlWindowOnWorker(
        const SqlWindowRequest(path: '/opfs/x.db', sql: 'SELECT 1'),
      ),
      throwsUnsupportedError,
    );
  });
}
