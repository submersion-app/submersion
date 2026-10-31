import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';

import '../../../../helpers/test_database.dart';

/// A repetitive series swaps its other dives into the editor with loadPlan,
/// which leaves the notifier's loaded plan on the saved dive (issue #3565).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('only the plan that was saved reads as persisted', () async {
    final notifier = DivePlanNotifier(
      PlanCalculatorService(),
      repository: DivePlanRepository(),
    );
    addTearDown(notifier.dispose);
    late DivePlanState current;
    notifier.addListener((state) => current = state);
    notifier.addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    expect(notifier.isPersisted, isFalse);

    await notifier.save();
    final saved = current;
    expect(notifier.isPersisted, isTrue);

    notifier.loadPlan(saved.copyWith(id: 'another-dive'));
    expect(notifier.isPersisted, isFalse);

    notifier.loadPlan(saved);
    expect(notifier.isPersisted, isTrue);
  });
}
