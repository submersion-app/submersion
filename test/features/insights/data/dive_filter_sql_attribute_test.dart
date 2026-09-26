import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';

void main() {
  const hose = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('each condition becomes its own attribute EXISTS, in order', () {
    final suit = EquipmentAttrCondition.suitThickness(min: 5.0, max: 7.0);
    final result = buildFilteredDiveIdSubquery(
      DiveFilterState(equipmentAttrConditions: [hose, suit]),
    );
    // One correlated probe of equipment_attributes per condition, and every
    // value bound in declaration order: the hose key first, then the suit
    // key with its bounds (#2365 compiles the axis from the registry).
    expect(
      'equipment_attributes'.allMatches(result.subquery).length,
      2,
      reason: result.subquery,
    );
    expect(
      result.params,
      containsAllInOrder([hose.key, 'thickness_mm', 5.0, 7.0]),
    );
  });

  test('no conditions, no attribute SQL', () {
    final result = buildFilteredDiveIdSubquery(const DiveFilterState());
    expect(result.subquery, isNot(contains('equipment_attributes')));
  });

  test('hasActiveFilters reflects the conditions', () {
    expect(
      const DiveFilterState(equipmentAttrConditions: [hose]).hasActiveFilters,
      isTrue,
    );
    expect(const DiveFilterState().hasActiveFilters, isFalse);
  });

  test('copyWith sets and clears the conditions', () {
    final set = const DiveFilterState().copyWith(
      equipmentAttrConditions: [hose],
    );
    expect(set.equipmentAttrConditions, [hose]);
    expect(
      set.copyWith(clearEquipmentAttrConditions: true).equipmentAttrConditions,
      isEmpty,
    );
  });
}
