import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/query/presentation/dive_query_chips.dart';

void main() {
  final depth = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30.48, null),
  );
  final noWeights = ConditionNode(
    FieldPath(['weights']),
    QueryOp.isEmpty,
    null,
  );
  final either = OrNode([
    ConditionNode(FieldPath(['waterTemp']), QueryOp.isEmpty, null),
    noWeights,
  ]);

  test('one chip per top-level AND child, printed in the diver unit', () {
    expect(diveQueryChipLabels(AndNode([depth, noWeights]), kMetricPrefs), [
      'depth > 30.48',
      'weights:none',
    ]);
    const feet = UnitPrefs(
      depth: DepthUnit.feet,
      temperature: TemperatureUnit.celsius,
      pressure: PressureUnit.bar,
      weight: WeightUnit.kilograms,
      volume: VolumeUnit.liters,
    );
    expect(diveQueryChipLabels(AndNode([depth]), feet), ['depth > 100']);
  });

  test('an OR at the top is one chip; null is none', () {
    expect(diveQueryChipLabels(either, kMetricPrefs), [
      'waterTemp:none OR weights:none',
    ]);
    expect(diveQueryChipLabels(null, kMetricPrefs), isEmpty);
  });

  test('removing a chip removes exactly its child', () {
    final filter = DiveFilterState(
      query: AndNode([depth, noWeights]),
      siteId: 's1',
    );
    final one = removeDiveQueryChip(filter, 0);
    expect(one.query, noWeights);
    expect(one.siteId, 's1');
    expect(removeDiveQueryChip(one, 0).query, isNull);
    expect(removeDiveQueryChip(one, 0).hasActiveFilters, isTrue);
  });
}
