import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';

const _log = LoggerService('ChangeLogOperationUndo');

/// An Undo that reverts one change log operation: everything a bulk action
/// filed under it with `ChangeLogScope.bulk` (bulk delete, Remove source,
/// Remove duplicate cylinders).
///
/// Returns whether the entry brought back everything it holds. A failure
/// costs only this route, since logging never blocks work: the entry may be
/// missing (no database to log to) or short.
Future<bool> undoChangeLogOperation(
  String? operationId, {
  ChangeLogRepository? changeLog,
  ChangeLogRevertService? revert,
}) async {
  if (operationId == null) return false;
  try {
    await (changeLog ?? ChangeLogRepository()).settleAll();
    final service = revert ?? ChangeLogRevertService();
    final result = await service.execute(
      await service.planOperation(operationId),
    );
    if (result.kept > 0) {
      _log.warning('Undo left ${result.kept} records behind');
    }
    return result.kept == 0;
  } catch (error, stackTrace) {
    _log.warning(
      'Could not undo change log operation $operationId',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}
