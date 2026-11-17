import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('HeldWriteUndo');

/// Runs [write], the save of a sitting; if it fails, takes back what the
/// sitting's held writes did outside the database (a relink's new bookmark,
/// issue #4527), then lets the failure through.
///
/// [takeUndo] is asked only when the save fails, and hands over the steps
/// the held writes recorded (null when none ran); the caller clears its own
/// record of them there, so they run once. Each step is on its own: one
/// that fails is logged as taking back [what], and the rest still run.
Future<T> undoHeldWritesOnFailure<T>(
  Future<T> Function() write, {
  required List<Future<void> Function()>? Function() takeUndo,
  required String what,
}) async {
  try {
    return await write();
  } catch (_) {
    for (final step in takeUndo() ?? const <Future<void> Function()>[]) {
      try {
        await step();
      } catch (error, stackTrace) {
        _log.warning(
          'Taking back $what that did not commit failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    rethrow;
  }
}
