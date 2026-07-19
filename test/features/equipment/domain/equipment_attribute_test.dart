import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

void main() {
  group('EquipmentAttribute.curatedId', () {
    test('is deterministic and namespaced by equipment id and key', () {
      expect(
        EquipmentAttribute.curatedId('e1', 'thickness_mm'),
        'attr_e1_thickness_mm',
      );
      // Same inputs on any device produce the same id -> sync convergence.
      expect(
        EquipmentAttribute.curatedId('e1', 'thickness_mm'),
        EquipmentAttribute.curatedId('e1', 'thickness_mm'),
      );
    });
  });

  group('EquipmentAttribute.curated', () {
    test('assigns the deterministic id and leaves isCustom false', () {
      final attr = EquipmentAttribute.curated(
        equipmentId: 'e1',
        key: 'buoyancy_kg',
        valueNum: 2.5,
      );
      expect(attr.id, EquipmentAttribute.curatedId('e1', 'buoyancy_kg'));
      expect(attr.isCustom, isFalse);
      expect(attr.valueNum, 2.5);
      expect(attr.sortOrder, 0);
    });
  });

  group('hasValue', () {
    EquipmentAttribute a({String? text, double? num}) => EquipmentAttribute(
      id: 'a1',
      equipmentId: 'e1',
      key: 'k',
      valueText: text,
      valueNum: num,
    );

    test('true when text is non-blank', () {
      expect(a(text: 'x').hasValue, isTrue);
    });

    test('true when a number is present (including zero)', () {
      expect(a(num: 0).hasValue, isTrue);
      expect(a(num: 5).hasValue, isTrue);
    });

    test('false when text is null, empty, or whitespace and num is null', () {
      expect(a().hasValue, isFalse);
      expect(a(text: '').hasValue, isFalse);
      expect(a(text: '   ').hasValue, isFalse);
    });
  });

  group('copyWith', () {
    const base = EquipmentAttribute(
      id: 'a1',
      equipmentId: 'e1',
      key: 'k',
      isCustom: true,
      valueText: 'orig',
      valueNum: 1,
      sortOrder: 3,
    );

    test('overrides only the provided fields', () {
      final next = base.copyWith(key: 'k2', sortOrder: 9);
      expect(next.key, 'k2');
      expect(next.sortOrder, 9);
      // Untouched fields carry through.
      expect(next.id, 'a1');
      expect(next.equipmentId, 'e1');
      expect(next.isCustom, isTrue);
      expect(next.valueText, 'orig');
      expect(next.valueNum, 1);
    });

    test('clear flags win over passthrough and any provided value', () {
      final cleared = base.copyWith(
        valueText: 'ignored',
        clearValueText: true,
        clearValueNum: true,
      );
      expect(cleared.valueText, isNull);
      expect(cleared.valueNum, isNull);
    });
  });

  group('equality (Equatable props)', () {
    EquipmentAttribute make({int sortOrder = 0}) => EquipmentAttribute(
      id: 'a1',
      equipmentId: 'e1',
      key: 'k',
      valueText: 't',
      valueNum: 2,
      sortOrder: sortOrder,
    );

    test('equal when every prop matches', () {
      expect(make(), make());
    });

    test('differs when any prop diverges', () {
      expect(make(sortOrder: 1), isNot(make(sortOrder: 2)));
    });
  });
}
