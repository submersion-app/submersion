import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

EquipmentItem _item(String id, EquipmentType type) =>
    EquipmentItem(id: id, name: id, type: type);

void main() {
  group('EquipmentFilterState', () {
    test('the default state narrows nothing', () {
      const filter = EquipmentFilterState();

      expect(filter.hasActiveFilters, isFalse);
      expect(filter.hasStatusFilter, isFalse);
    });

    test('each axis on its own counts as active', () {
      expect(
        const EquipmentFilterState(
          status: EquipmentStatus.retired,
        ).hasActiveFilters,
        isTrue,
      );
      expect(
        const EquipmentFilterState(serviceDueOnly: true).hasActiveFilters,
        isTrue,
      );
      expect(
        const EquipmentFilterState(type: EquipmentType.bcd).hasActiveFilters,
        isTrue,
      );
      // The category is not a status narrowing, so it must not make the list
      // read a different provider.
      expect(
        const EquipmentFilterState(type: EquipmentType.bcd).hasStatusFilter,
        isFalse,
      );
    });

    test('service due and a status cannot both be set', () {
      expect(
        () => EquipmentFilterState(
          status: EquipmentStatus.retired,
          serviceDueOnly: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('apply keeps only the selected category', () {
      final equipment = [
        _item('reg', EquipmentType.regulator),
        _item('bcd', EquipmentType.bcd),
        _item('suit', EquipmentType.wetsuit),
      ];

      const filter = EquipmentFilterState(type: EquipmentType.bcd);
      expect(filter.apply(equipment).map((e) => e.id), ['bcd']);
    });

    test('apply passes the list through when no category is selected', () {
      final equipment = [_item('reg', EquipmentType.regulator)];

      expect(const EquipmentFilterState().apply(equipment), same(equipment));
    });

    test('clearStatus resets both halves of the status axis', () {
      const serviceDue = EquipmentFilterState(
        serviceDueOnly: true,
        type: EquipmentType.bcd,
      );
      final cleared = serviceDue.copyWith(clearStatus: true);

      expect(cleared.serviceDueOnly, isFalse);
      expect(cleared.status, isNull);
      // The other axis is untouched.
      expect(cleared.type, EquipmentType.bcd);
    });

    test('clearType leaves the status axis alone', () {
      const filter = EquipmentFilterState(
        status: EquipmentStatus.retired,
        type: EquipmentType.bcd,
      );
      final cleared = filter.copyWith(clearType: true);

      expect(cleared.type, isNull);
      expect(cleared.status, EquipmentStatus.retired);
    });

    test('value equality lets the provider skip identical rebuilds', () {
      expect(
        const EquipmentFilterState(
          status: EquipmentStatus.retired,
          type: EquipmentType.bcd,
        ),
        const EquipmentFilterState(
          status: EquipmentStatus.retired,
          type: EquipmentType.bcd,
        ),
      );
      expect(
        const EquipmentFilterState(status: EquipmentStatus.retired),
        isNot(const EquipmentFilterState(status: EquipmentStatus.lost)),
      );
    });

    const hp = EquipmentAttrCondition(
      key: 'hose_type',
      choices: {'hp'},
      types: {EquipmentType.hose},
    );

    EquipmentItem hose(String id, String kind) => EquipmentItem(
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

    test('apply narrows by the category and then each condition', () {
      final equipment = [
        hose('hp1', 'hp'),
        hose('lp1', 'lp'),
        _item('bcd', EquipmentType.bcd),
      ];
      const filter = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: [hp],
      );
      expect(filter.apply(equipment).map((e) => e.id), ['hp1']);
      expect(filter.hasActiveFilters, isTrue);
    });

    test('changing or clearing the category drops the conditions', () {
      const filter = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: [hp],
      );
      expect(filter.copyWith(type: EquipmentType.bcd).attrConditions, isEmpty);
      expect(filter.copyWith(clearType: true).attrConditions, isEmpty);
      expect(filter.copyWith(type: EquipmentType.hose).attrConditions, [hp]);
      expect(filter.copyWith(status: EquipmentStatus.retired).attrConditions, [
        hp,
      ]);
      expect(
        filter.copyWith(clearAttrConditions: true).attrConditions,
        isEmpty,
      );
    });

    test('equality includes the conditions', () {
      const a = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: [hp],
      );
      // A list built at runtime, so equality has to compare the elements
      // rather than the canonicalized const instance.
      final b = EquipmentFilterState(
        type: EquipmentType.hose,
        attrConditions: List.of(const [
          EquipmentAttrCondition(
            key: 'hose_type',
            choices: {'hp'},
            types: {EquipmentType.hose},
          ),
        ]),
      );
      expect(identical(a.attrConditions, b.attrConditions), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const EquipmentFilterState(type: EquipmentType.hose)));
    });
  });
}
