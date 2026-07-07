import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/maintenance/startup_maintenance_task.dart';

class _RecordingTask implements StartupMaintenanceTask {
  _RecordingTask(this.name, this._log, {this.throws = false});

  @override
  final String name;
  final List<String> _log;
  final bool throws;

  @override
  Future<void> run() async {
    _log.add(name);
    if (throws) throw StateError('boom in $name');
  }
}

void main() {
  test('runs every task in order', () async {
    final calls = <String>[];
    await StartupMaintenanceRunner([
      _RecordingTask('a', calls),
      _RecordingTask('b', calls),
      _RecordingTask('c', calls),
    ]).run();
    expect(calls, ['a', 'b', 'c']);
  });

  test('a throwing task is isolated: later tasks still run', () async {
    final calls = <String>[];
    await StartupMaintenanceRunner([
      _RecordingTask('a', calls),
      _RecordingTask('b', calls, throws: true),
      _RecordingTask('c', calls),
    ]).run();
    // 'b' ran (and threw) but 'c' still ran; run() completed normally.
    expect(calls, ['a', 'b', 'c']);
  });

  test('an empty task list is a no-op', () async {
    await StartupMaintenanceRunner(const []).run();
  });
}
