import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_log_state.dart';

void main() {
  final when = DateTime.utc(2026, 11, 14, 9);

  group('PlanLogState.of', () {
    test('a dive with no entry in the log is only planned', () {
      expect(PlanLogState.of(null), PlanLogState.planned);
    });

    test('an entry still marked planned is in the log as planned', () {
      final entry = Dive(id: 'd1', dateTime: when, isPlanned: true);
      expect(PlanLogState.of(entry), PlanLogState.loggedAsPlanned);
    });

    test('an entry no longer planned has been dived', () {
      final entry = Dive(id: 'd1', dateTime: when);
      expect(PlanLogState.of(entry), PlanLogState.dived);
    });
  });

  test('the planned flag alone reads by the same rule', () {
    expect(PlanLogState.ofPlannedFlag(null), PlanLogState.planned);
    expect(PlanLogState.ofPlannedFlag(true), PlanLogState.loggedAsPlanned);
    expect(PlanLogState.ofPlannedFlag(false), PlanLogState.dived);
  });

  test('wire names are the snake_case the agent documents use', () {
    expect(PlanLogState.planned.wireName, 'planned');
    expect(PlanLogState.loggedAsPlanned.wireName, 'logged_as_planned');
    expect(PlanLogState.dived.wireName, 'dived');
  });
}
