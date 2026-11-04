import 'package:submersion/features/agent_access/data/writes/write_plan.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Plans waiting to be applied. They live in memory: the protocol builds a
/// server per request, so this outlives any one of them, but a plan never
/// outlives the app, and a stale one could not be applied anyway.
class WritePlanStore {
  WritePlanStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _plans = <String, WritePlan>{};

  int get length => _plans.length;

  void put(WritePlan plan) {
    _plans.removeWhere((_, held) => _expired(held));
    _plans[plan.id] = plan;
  }

  /// Hands over [id], once: an apply that fails starts again from a preview.
  WritePlan take(String id) {
    final plan = _plans.remove(id);
    if (plan == null) {
      throw AgentToolException(
        AgentToolErrorCode.planNotFound,
        'No plan has this id, or it was already used. Call preview_changes.',
        details: {'plan_id': id},
      );
    }
    if (_expired(plan)) {
      throw AgentToolException(
        AgentToolErrorCode.planExpired,
        'This plan expired. Call preview_changes again.',
        details: {'plan_id': id},
      );
    }
    return plan;
  }

  bool _expired(WritePlan plan) => _clock().isAfter(plan.expiresAt);
}
