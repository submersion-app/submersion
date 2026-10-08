import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

void main() {
  test(
    'a non-default owner counts as an active filter and survives copyWith',
    () {
      const f = EquipmentFilterState(owner: EquipmentOwnerFilter.mine);
      expect(f.hasActiveFilters, isTrue);
      expect(f.copyWith(clearType: true).owner, EquipmentOwnerFilter.mine);
      expect(f, const EquipmentFilterState(owner: EquipmentOwnerFilter.mine));
      expect(f == const EquipmentFilterState(), isFalse);
    },
  );
}
