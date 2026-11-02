import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Runs a plan `preview_changes` returned.
class ApplyChangesTool implements AgentTool {
  ApplyChangesTool({
    required WritePlanStore store,
    required WriteApplier applier,
  }) : _store = store,
       _applier = applier;

  final WritePlanStore _store;
  final WriteApplier _applier;

  @override
  String get name => 'apply_changes';

  @override
  String get description =>
      'Second of two steps to change the logbook: runs a plan from '
      'preview_changes. All of it applies or none does. The diver may be '
      'asked to allow it inside Submersion, so this can wait up to five '
      'minutes; give the call a timeout longer than that where you can. If '
      'your call times out the diver may still allow it, so read the records '
      'before trying again. Refusing answers not_confirmed. A record changed '
      'since the preview refuses the whole plan with plan_stale, and a plan '
      'is good for one call, so preview again after any refusal. Returns one '
      'change log operation per diver touched; pass an operation_id to '
      'revert_operation to undo it.';

  @override
  Map<String, Object?> get inputSchema => {
    'type': 'object',
    'properties': {
      'plan_id': {
        'type': 'string',
        'description': 'The plan_id preview_changes returned.',
      },
    },
    'required': ['plan_id'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final id = args['plan_id'];
    if (id is! String || id.isEmpty) {
      throw const AgentToolException(
        AgentToolErrorCode.invalidArgument,
        'plan_id is required.',
      );
    }
    final result = await _applier.apply(context.db, _store.take(id));
    return result.toJson();
  }
}
