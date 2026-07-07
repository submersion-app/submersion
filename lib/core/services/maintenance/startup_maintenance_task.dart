import 'package:submersion/core/services/logger_service.dart';

/// A cleanup/backfill task run once per launch, after the database is open.
///
/// Tasks exist to reconcile data that older app versions left in an incomplete
/// state (e.g. backfilling values a feature now expects). They run on every
/// launch rather than being gated to a single schema migration, so they also
/// self-heal after a database restore — which reopens an older database in-app,
/// past the migration path. That makes idempotency the core contract:
///
/// - [run] MUST be safe to invoke on every launch. Once its work is done it
///   should become a cheap no-op (typically by scoping its own query to the
///   rows that still need it, so a completed task finds nothing to do).
/// - [run] MUST NOT assume it is the first time it has run.
///
/// The [StartupMaintenanceRunner] invokes tasks best-effort: a throwing task is
/// logged and does not prevent the others (or app startup) from proceeding.
abstract interface class StartupMaintenanceTask {
  /// Stable, human-readable identifier used in logs.
  String get name;

  /// Perform the task. Must be idempotent (see class docs).
  Future<void> run();
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
  /// remaining tasks still run.
  Future<void> run() async {
    for (final task in _tasks) {
      try {
        await task.run();
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
