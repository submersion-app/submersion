import 'package:submersion/features/agent_access/data/writes/write_plan.dart';

/// What the diver is asked to allow.
class WriteConfirmation {
  const WriteConfirmation({
    required this.clientName,
    required this.label,
    required this.countsByEntity,
    required this.countsByDiver,
    required this.items,
  });

  WriteConfirmation.of(WritePlan plan)
    : clientName = plan.clientName,
      label = plan.label,
      countsByEntity = plan.countsByEntity,
      countsByDiver = plan.countsByDiver,
      items = plan.items;

  /// The MCP client's name, when it sent one.
  final String? clientName;
  final String label;
  final Map<String, int> countsByEntity;
  final Map<String, int> countsByDiver;
  final List<PlanItem> items;
}

/// Asks the diver inside the app whether a plan may run.
abstract interface class WriteConfirmer {
  /// True to allow it. A dialog that times out answers false.
  Future<bool> confirm(WriteConfirmation request);
}
