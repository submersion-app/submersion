import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';

DivePlanSummary _summary(String id) =>
    DivePlanSummary(id: id, name: 'plan $id', updatedAt: DateTime(2026, 7, 22));

void main() {
  test('planIsPersisted is true when the id is in the summaries', () {
    final summaries = [_summary('a'), _summary('b')];
    expect(planIsPersisted('a', summaries), isTrue);
  });

  test('planIsPersisted is false when the id is absent', () {
    final summaries = [_summary('a')];
    expect(planIsPersisted('z', summaries), isFalse);
  });

  test('planIsPersisted is false for an empty list', () {
    expect(planIsPersisted('a', const []), isFalse);
  });
}
