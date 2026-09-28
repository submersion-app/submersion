import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

/// The equipment list's tag axis (issue #1942).
void main() {
  test('a tag selection counts as an active filter', () {
    expect(
      const EquipmentFilterState(tagIds: {'travel'}).hasActiveFilters,
      isTrue,
    );
    expect(
      const EquipmentFilterState(tagIds: {'travel'}).hasStatusFilter,
      isFalse,
    );
  });

  test('clearTagIds empties the axis and leaves the others', () {
    const filter = EquipmentFilterState(
      status: EquipmentStatus.retired,
      type: EquipmentType.bcd,
      tagIds: {'travel'},
    );
    final cleared = filter.copyWith(clearTagIds: true);
    expect(cleared.tagIds, isEmpty);
    expect(cleared.status, EquipmentStatus.retired);
    expect(cleared.type, EquipmentType.bcd);
  });

  test('a new category keeps the tags; other axes keep them too', () {
    const filter = EquipmentFilterState(tagIds: {'travel'});
    expect(filter.copyWith(type: EquipmentType.bcd).tagIds, {'travel'});
    expect(filter.copyWith(clearStatus: true).tagIds, {'travel'});
    expect(filter.copyWith(tagIds: {'rental'}).tagIds, {'rental'});
  });

  test('equality compares the tag sets by value', () {
    const a = EquipmentFilterState(tagIds: {'a', 'b'});
    // Built at runtime, so equality must compare elements, not identity.
    final reversed = ['b', 'a'];
    final b = EquipmentFilterState(tagIds: {...reversed});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const EquipmentFilterState(tagIds: {'a'})));
    expect(a, isNot(const EquipmentFilterState()));
  });
}
