import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/utils/plan_mode_grouping.dart';

DivePlanSummary _p(String id, PlanMode mode) => DivePlanSummary(
  id: id,
  name: id,
  updatedAt: DateTime(2026, 1, 1),
  mode: mode,
);

void main() {
  group('groupPlansByMode', () {
    test('groups plans under their mode', () {
      final groups = groupPlansByMode([
        _p('a', PlanMode.oc),
        _p('b', PlanMode.ccr),
        _p('c', PlanMode.oc),
      ]);

      expect(groups.map((g) => g.mode), [PlanMode.oc, PlanMode.ccr]);
      expect(groups.first.plans.map((p) => p.id), ['a', 'c']);
      expect(groups.last.plans.map((p) => p.id), ['b']);
    });

    test('orders groups by PlanMode declaration order, not input order', () {
      final groups = groupPlansByMode([
        _p('a', PlanMode.pscr),
        _p('b', PlanMode.oc),
        _p('c', PlanMode.scr),
        _p('d', PlanMode.ccr),
      ]);

      expect(groups.map((g) => g.mode), [
        PlanMode.oc,
        PlanMode.ccr,
        PlanMode.scr,
        PlanMode.pscr,
      ]);
    });

    test('omits modes with no plans rather than yielding an empty group', () {
      final groups = groupPlansByMode([_p('a', PlanMode.oc)]);

      expect(groups, hasLength(1));
      expect(groups.single.mode, PlanMode.oc);
    });

    test('an empty input yields no groups', () {
      expect(groupPlansByMode(const []), isEmpty);
    });

    test('preserves the input order of plans within a group', () {
      final groups = groupPlansByMode([
        _p('newest', PlanMode.oc),
        _p('oldest', PlanMode.oc),
      ]);

      expect(groups.single.plans.map((p) => p.id), ['newest', 'oldest']);
    });
  });
}
