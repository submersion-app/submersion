import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  test('attribute axis compiles to a dive_equipment join', () {
    final result = buildFilteredDiveIdSubquery(
      const DiveFilterState(
        equipmentAttrKey: 'thickness_mm',
        equipmentAttrMin: 5.0,
        equipmentAttrMax: 7.0,
      ),
    );
    expect(result.subquery, contains('dive_equipment'));
    expect(result.subquery, contains('equipment_attributes'));
    expect(result.subquery, contains('ea.attr_key = ?'));
    expect(result.subquery, contains('ea.value_num >= ?'));
    expect(result.subquery, contains('ea.value_num <= ?'));
    // Suit thickness is restricted to exposure suits, mirroring
    // getDivesBySuitThickness().
    expect(result.subquery, contains("eqf.type IN ('wetsuit', 'drysuit')"));
    expect(result.params, ['thickness_mm', 5.0, 7.0]);
  });

  test('choice variant binds value_text and is not suit-restricted', () {
    final result = buildFilteredDiveIdSubquery(
      const DiveFilterState(
        equipmentAttrKey: 'valve_type',
        equipmentAttrChoice: 'din',
      ),
    );
    expect(result.subquery, contains('ea.value_text = ?'));
    // Only thickness_mm carries the suit-type restriction.
    expect(result.subquery, isNot(contains("eqf.type IN")));
    expect(result.params, ['valve_type', 'din']);
  });

  test('no attribute axis -> no attribute SQL', () {
    final result = buildFilteredDiveIdSubquery(const DiveFilterState());
    expect(result.subquery, isNot(contains('equipment_attributes')));
  });

  test('hasActiveFilters reflects the attribute axis', () {
    expect(
      const DiveFilterState(equipmentAttrKey: 'thickness_mm').hasActiveFilters,
      isTrue,
    );
    expect(const DiveFilterState().hasActiveFilters, isFalse);
  });
}
