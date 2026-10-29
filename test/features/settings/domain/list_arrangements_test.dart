import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';

void main() {
  const full = ListArrangements(
    diveSort: 'a',
    divePlanSort: 'b',
    tripSort: 'c',
    courseSort: 'd',
    buddySort: 'e',
    diveCenterSort: 'f',
    siteSort: 'g',
    certificationSort: 'h',
    equipmentSort: 'i',
    siteGroupBy: 'j',
    certificationGroupBy: 'k',
    equipmentArrangement: 'l',
    equipmentGroupByLocation: true,
  );

  test('none holds no saved value', () {
    expect(ListArrangements.none, const ListArrangements());
    expect(ListArrangements.none.diveSort, isNull);
    expect(ListArrangements.none.equipmentGroupByLocation, isNull);
  });

  test('copyWith keeps unset fields', () {
    final changed = full.copyWith(siteSort: 'z');
    expect(changed.siteSort, 'z');
    expect(changed, full.copyWith(siteSort: 'z'));
    expect(changed.copyWith(siteSort: 'g'), full);
  });

  test('equality covers every field', () {
    final variants = [
      full.copyWith(diveSort: 'x'),
      full.copyWith(divePlanSort: 'x'),
      full.copyWith(tripSort: 'x'),
      full.copyWith(courseSort: 'x'),
      full.copyWith(buddySort: 'x'),
      full.copyWith(diveCenterSort: 'x'),
      full.copyWith(siteSort: 'x'),
      full.copyWith(certificationSort: 'x'),
      full.copyWith(equipmentSort: 'x'),
      full.copyWith(siteGroupBy: 'x'),
      full.copyWith(certificationGroupBy: 'x'),
      full.copyWith(equipmentArrangement: 'x'),
      full.copyWith(equipmentGroupByLocation: false),
    ];
    for (final v in variants) {
      expect(v, isNot(full));
      expect(v.hashCode, isNot(full.hashCode));
    }
  });
}
