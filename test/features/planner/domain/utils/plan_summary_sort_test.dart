import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/utils/plan_summary_sort.dart';

DivePlanSummary _p(
  String id, {
  DateTime? updatedAt,
  double? maxDepth,
  String? name,
}) => DivePlanSummary(
  id: id,
  name: name ?? id,
  updatedAt: updatedAt ?? DateTime(2026, 1, 1),
  maxDepth: maxDepth,
);

void main() {
  group('sortPlanSummaries', () {
    test('sorts by date descending by default', () {
      final plans = [
        _p('old', updatedAt: DateTime(2026, 1, 1)),
        _p('new', updatedAt: DateTime(2026, 6, 1)),
      ];

      final sorted = sortPlanSummaries(
        plans,
        const SortState(field: DivePlanSortField.date),
      );

      expect(sorted.map((p) => p.id), ['new', 'old']);
    });

    test('ascending date puts the oldest plan first', () {
      final plans = [
        _p('new', updatedAt: DateTime(2026, 6, 1)),
        _p('old', updatedAt: DateTime(2026, 1, 1)),
      ];

      final sorted = sortPlanSummaries(
        plans,
        const SortState(
          field: DivePlanSortField.date,
          direction: SortDirection.ascending,
        ),
      );

      expect(sorted.map((p) => p.id), ['old', 'new']);
    });

    test('a plan with no computed depth sorts as if its depth were zero', () {
      final plans = [
        _p('shallow', maxDepth: 5.0),
        _p('unknown', maxDepth: null),
      ];

      final sorted = sortPlanSummaries(
        plans,
        const SortState(
          field: DivePlanSortField.depth,
          direction: SortDirection.ascending,
        ),
      );

      expect(sorted.map((p) => p.id), ['unknown', 'shallow']);
    });

    // Text fields invert direction, matching DiveSortField.site: "ascending"
    // reads Z-to-A for a name, "descending" reads A-to-Z, so the same button
    // keeps meaning "high to low" for every field, numeric or text.
    test('ascending name reads Z-to-A, case- and accent-insensitive', () {
      final plans = [_p('a', name: 'Écueil'), _p('b', name: 'Zebra')];

      final sorted = sortPlanSummaries(
        plans,
        const SortState(
          field: DivePlanSortField.name,
          direction: SortDirection.ascending,
        ),
      );

      expect(sorted.map((p) => p.id), ['b', 'a']);
    });

    test('descending name reads A-to-Z', () {
      final plans = [_p('a', name: 'Alpha'), _p('b', name: 'Bravo')];

      final sorted = sortPlanSummaries(
        plans,
        const SortState(
          field: DivePlanSortField.name,
          direction: SortDirection.descending,
        ),
      );

      expect(sorted.map((p) => p.id), ['a', 'b']);
    });

    test('does not mutate the input list', () {
      final plans = [
        _p('old', updatedAt: DateTime(2026, 1, 1)),
        _p('new', updatedAt: DateTime(2026, 6, 1)),
      ];

      sortPlanSummaries(plans, const SortState(field: DivePlanSortField.date));

      expect(plans.map((p) => p.id), ['old', 'new']);
    });
  });
}
