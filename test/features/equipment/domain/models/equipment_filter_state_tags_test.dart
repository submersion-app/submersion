import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

EquipmentItem _item(String id, EquipmentType type) =>
    EquipmentItem(id: id, name: id, type: type);

EquipmentItem _hose(String id, String kind) => EquipmentItem(
  id: id,
  name: id,
  type: EquipmentType.hose,
  attributes: [
    EquipmentAttribute.curated(
      equipmentId: id,
      key: 'hose_type',
      valueText: kind,
    ),
  ],
);

/// The equipment list's tag axis (issue #1942).
void main() {
  final all = [
    _item('wing', EquipmentType.bcd),
    _item('reg', EquipmentType.regulator),
    _item('mask', EquipmentType.mask),
  ];
  const tagIdsByEquipment = {
    'wing': ['travel', 'rental'],
    'reg': ['travel'],
  };

  List<String> ids(EquipmentFilterState filter) => [
    for (final e in filter.apply(all, tagIdsByEquipment)) e.id,
  ];

  test('an item matches when it carries any selected tag', () {
    expect(ids(const EquipmentFilterState(tagIds: {'rental'})), ['wing']);
    expect(ids(const EquipmentFilterState(tagIds: {'rental', 'travel'})), [
      'wing',
      'reg',
    ]);
  });

  test('an item without tags never matches a tag filter', () {
    expect(ids(const EquipmentFilterState(tagIds: {'travel'})), [
      'wing',
      'reg',
    ]);
  });

  test('the tag axis is ANDed with the category', () {
    expect(
      ids(
        const EquipmentFilterState(
          type: EquipmentType.regulator,
          tagIds: {'rental'},
        ),
      ),
      isEmpty,
    );
    expect(
      ids(
        const EquipmentFilterState(
          type: EquipmentType.regulator,
          tagIds: {'travel'},
        ),
      ),
      ['reg'],
    );
  });

  test('the tag axis is ANDed with attribute conditions', () {
    final hoses = [_hose('hp1', 'hp'), _hose('hp2', 'hp'), _hose('lp1', 'lp')];
    const filter = EquipmentFilterState(
      type: EquipmentType.hose,
      attrConditions: [
        EquipmentAttrCondition(
          key: 'hose_type',
          choices: {'hp'},
          types: {EquipmentType.hose},
        ),
      ],
      tagIds: {'travel'},
    );
    final result = filter.apply(hoses, const {
      'hp1': ['travel'],
      'lp1': ['travel'],
    });
    expect(result.map((e) => e.id), ['hp1']);
  });

  test('no tag selected passes the list through', () {
    expect(
      const EquipmentFilterState().apply(all, tagIdsByEquipment),
      same(all),
    );
  });

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

  group('tagsEmptied', () {
    bool emptied(EquipmentFilterState filter) =>
        filter.tagsEmptied(all, tagIdsByEquipment);

    test('is true when the category holds items but none carries a tag', () {
      // The mask is the only mask, and it has no tags.
      expect(
        emptied(
          const EquipmentFilterState(
            type: EquipmentType.mask,
            tagIds: {'travel'},
          ),
        ),
        isTrue,
      );
      expect(emptied(const EquipmentFilterState(tagIds: {'unused'})), isTrue);
    });

    test('is false when the category itself holds nothing', () {
      expect(
        emptied(
          const EquipmentFilterState(
            type: EquipmentType.fins,
            tagIds: {'travel'},
          ),
        ),
        isFalse,
      );
    });

    test('is false with no tag selected or with a tag match', () {
      expect(emptied(const EquipmentFilterState()), isFalse);
      expect(
        emptied(
          const EquipmentFilterState(
            type: EquipmentType.bcd,
            tagIds: {'travel'},
          ),
        ),
        isFalse,
      );
    });
  });
}
