import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  const hose = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );

  test('each condition becomes the shared EXISTS clause, in order', () {
    final suit = EquipmentAttrCondition.suitThickness(min: 5.0, max: 7.0);
    final result = buildFilteredDiveIdSubquery(
      DiveFilterState(equipmentAttrConditions: [hose, suit]),
    );
    final hoseSql = equipmentAttrConditionSql(hose, diveIdRef: 'dives.id');
    final suitSql = equipmentAttrConditionSql(suit, diveIdRef: 'dives.id');
    expect(result.subquery, contains(hoseSql.sql));
    expect(result.subquery, contains(suitSql.sql));
    expect(result.params, [...hoseSql.params, ...suitSql.params]);
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
