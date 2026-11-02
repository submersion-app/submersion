import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';

/// Undoes a change log operation the way the app's own Revert does.
class RevertOperationTool implements AgentTool {
  RevertOperationTool({
    required ChangeLogRevertService revert,
    required ChangeLogRepository changeLog,
  }) : _revert = revert,
       _changeLog = changeLog;

  final ChangeLogRevertService _revert;
  final ChangeLogRepository _changeLog;

  @override
  String get name => 'revert_operation';

  @override
  String get description =>
      'Undoes a change log operation: an operation_id from apply_changes, or '
      'any other entry in the diver\'s change log. The change takes effect at '
      'once, without asking the diver, and is itself logged, so it can be '
      'reverted too. A record edited since the operation is left as it is and '
      'listed under kept_items, unless include_changed_since is true. Items '
      'that cannot go back, such as a record used by later data, are listed '
      'there too with a blocked reason.';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'operation_id': {'type': 'string'},
      'include_changed_since': {
        'type': 'boolean',
        'default': false,
        'description': 'Also overwrite what was edited after the operation.',
      },
    },
    'required': ['operation_id'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final id = args['operation_id'];
    if (id is! String || id.isEmpty) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'operation_id is required.',
      );
    }
    // The settle scheduler waits for a quiet period, so an entry written a
    // moment ago may not be readable yet.
    await _changeLog.settleAll();
    final operation = await _changeLog.getOperation(id);
    if (operation == null) {
      throw AgentToolException(
        AgentToolErrorCode.notFound,
        'No change log operation has this id.',
        details: {'operation_id': id},
      );
    }
    if (operation.revertedById != null) {
      throw AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'This operation was already reverted.',
        details: {'operation_id': id, 'reverted_by': operation.revertedById},
      );
    }
    final plan = await _revert.planOperation(id);
    final result = await _revert.execute(
      plan,
      includeChangedSince: args['include_changed_since'] == true,
    );
    return {
      'reverted': result.reverted,
      'kept': result.kept,
      'kept_items': [for (final item in result.keptItems) _kept(item)],
      'operation_id': result.operationId,
    };
  }

  Map<String, Object?> _kept(ChangeLogRevertItem item) => {
    'table': item.event.table,
    'id': item.event.recordId,
    'column': ?item.column,
    'changed_since': item.changedSince,
    'blocked': ?item.block?.name,
  };
}
