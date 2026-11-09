import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/presentation/utils/picker_group_folds.dart';

/// Equipment pickers start folded except where the ticks are (issue #3364).
void main() {
  test('opens only groups holding a tick', () {
    expect(
      initialOpenPickerGroups(
        {
          'type:bcd': ['b1', 'b2'],
          'type:tank': ['t1'],
          'type:fins': ['f1'],
        },
        {'t1'},
      ),
      {'type:tank'},
    );
  });

  test('a single group starts open even with nothing ticked', () {
    expect(
      initialOpenPickerGroups({
        'type:transmitter': ['x1', 'x2'],
      }, const {}),
      {'type:transmitter'},
    );
  });

  test('no groups gives no keys', () {
    expect(initialOpenPickerGroups(const {}, const {'a'}), isEmpty);
  });

  test('owner key and nested type key', () {
    expect(ownerFoldKey('d2'), 'owner:d2');
    expect(
      typeFoldKey(EquipmentType.bcd, locationKey: ownerFoldKey('d2')),
      'owner:d2/type:bcd',
    );
  });

  test('tickedIn counts only ticked ids', () {
    expect(tickedIn(['a', 'b', 'c'], {'b', 'c', 'z'}), 2);
    expect(tickedIn(['a'], const {}), 0);
  });
}
