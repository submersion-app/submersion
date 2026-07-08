import 'package:submersion/core/services/logger_service.dart';

/// Reports incremental progress within a task: [completed] work units done.
typedef MaintenanceProgressCallback = void Function(int completed);

/// Reports a task's progress to the UI: its [label], [completed] of [total].
typedef MaintenanceProgressReporter =
    void Function(String label, int completed, int total);

/// A cleanup/backfill task run once per launch, after the database is open.
///
/// Tasks reconcile data older app versions left incomplete. They run on every
/// launch (so they also self-heal after a database restore, which reopens an
/// older database in-app past the migration path), which makes idempotency the
/// core contract:
///
/// - [pendingWork] MUST be a cheap, indexed count of remaining units. It is
///   called on every launch; the runner only invokes [run] when it is > 0.
/// - [run] MUST be idempotent and drive [pendingWork] strictly toward 0 (record
///   handled entities durably - e.g. via MaintenanceLedgerRepository - so
///   items that cannot produce their normal artifact still drop out).
///
/// The [StartupMaintenanceRunner] invokes tasks best-effort: a throwing task is
/// logged and does not prevent the others (or app startup) from proceeding.
abstract interface class StartupMaintenanceTask {
  /// Stable, human-readable identifier used in logs.
  String get name;

  /// User-facing label shown on the startup progress bar.
  String get progressLabel;

  /// Cheap, indexed count of remaining work units (0 => nothing to do).
  Future<int> pendingWork();

  /// Perform the work. Only called when [pendingWork] > 0. [onProgress] is
  /// ticked with the running completed-count as each unit finishes.
  Future<void> run({MaintenanceProgressCallback? onProgress});
}

/// Runs a list of [StartupMaintenanceTask]s best-effort during startup.
///
/// Register new cleanup tasks by adding them to the list passed in at the
/// composition root; no changes here are needed.
class StartupMaintenanceRunner {
  final List<StartupMaintenanceTask> _tasks;
  final _log = LoggerService.forClass(StartupMaintenanceRunner);

  StartupMaintenanceRunner(this._tasks);

  /// Runs every task in order. Each is isolated: a failure is logged and the
  /// remaining tasks still run. Tasks with no pending work are skipped cheaply.
  Future<void> run({MaintenanceProgressReporter? onProgress}) async {
    for (final task in _tasks) {
      try {
        final total = await task.pendingWork();
        if (total == 0) continue; // cheap gate: skip the heavy path entirely

        onProgress?.call(task.progressLabel, 0, total);
        await task.run(
          onProgress: (done) =>
              onProgress?.call(task.progressLabel, done, total),
        );

        // Convergence safety net: if the backlog did not shrink, the task is
        // stuck (likely a persistent per-item failure) or growing. Log loudly
        // instead of silently repeating a startup hang on every future launch.
        final remaining = await task.pendingWork();
        if (remaining >= total) {
          _log.warning(
            'Startup maintenance task "${task.name}" did not reduce its '
            'backlog ($remaining of $total pending after run) - check earlier '
            'error logs.',
          );
        }
      } catch (e, stackTrace) {
        _log.error(
          'Startup maintenance task "${task.name}" failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
