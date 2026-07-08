import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/maintenance/startup_maintenance_task.dart';

class _FakeTask implements StartupMaintenanceTask {
  _FakeTask(
    this.name, {
    required int pending,
    this.throwsOnRun = false,
    this.convergesTo = 0,
    List<String>? runLog,
  }) : _pending = pending,
       _runLog = runLog;

  @override
  final String name;
  @override
  String get progressLabel => 'Doing $name';

  int _pending;
  final int convergesTo;
  final bool throwsOnRun;
  final List<String>? _runLog;

  @override
  Future<int> pendingWork() async => _pending;

  @override
  Future<void> run({MaintenanceProgressCallback? onProgress}) async {
    _runLog?.add(name);
    if (throwsOnRun) throw StateError('boom in $name');
    for (var i = 1; i <= _pending; i++) {
      onProgress?.call(i);
    }
    _pending = convergesTo; // simulate work reducing the backlog
  }
}

void main() {
  test('skips a task whose pendingWork is 0 (never calls run)', () async {
    final runLog = <String>[];
    await StartupMaintenanceRunner([
      _FakeTask('idle', pending: 0, runLog: runLog),
    ]).run();
    expect(runLog, isEmpty);
  });

  test('runs a task with work and reports progress with its label', () async {
    final events = <String>[];
    await StartupMaintenanceRunner([_FakeTask('backfill', pending: 3)]).run(
      onProgress: (label, done, total) => events.add('$label $done/$total'),
    );
    expect(events, [
      'Doing backfill 0/3',
      'Doing backfill 1/3',
      'Doing backfill 2/3',
      'Doing backfill 3/3',
    ]);
  });

  test('a throwing task is isolated: later tasks still run', () async {
    final runLog = <String>[];
    await StartupMaintenanceRunner([
      _FakeTask('a', pending: 1, runLog: runLog),
      _FakeTask('b', pending: 1, throwsOnRun: true, runLog: runLog),
      _FakeTask('c', pending: 1, runLog: runLog),
    ]).run();
    expect(runLog, ['a', 'b', 'c']);
  });

  test(
    'a task that does not converge does not throw (logged, not fatal)',
    () async {
      // pending stays at 2 after run(): the runner must complete normally.
      await StartupMaintenanceRunner([
        _FakeTask('stuck', pending: 2, convergesTo: 2),
      ]).run();
    },
  );

  test('an empty task list is a no-op', () async {
    await StartupMaintenanceRunner(const []).run();
  });
}
