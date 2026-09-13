import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';

EquipmentItem _item(
  String id,
  EquipmentType type, {
  String? key,
  String? text,
  double? num,
  bool custom = false,
}) => EquipmentItem(
  id: id,
  name: id,
  type: type,
  attributes: [
    if (key != null)
      custom
          ? EquipmentAttribute(
              id: 'c-$id',
              equipmentId: id,
              key: key,
              isCustom: true,
              valueText: text,
              valueNum: num,
            )
          : EquipmentAttribute.curated(
              equipmentId: id,
              key: key,
              valueText: text,
              valueNum: num,
            ),
  ],
);

void main() {
  group('EquipmentAttrCondition.matches', () {
    const hp = EquipmentAttrCondition(
      key: 'hose_type',
      choices: {'hp'},
      types: {EquipmentType.hose},
    );

    test('matches the chosen value on the right type', () {
      expect(
        hp.matches(
          _item('h', EquipmentType.hose, key: 'hose_type', text: 'hp'),
        ),
        isTrue,
      );
      expect(
        hp.matches(
          _item('h', EquipmentType.hose, key: 'hose_type', text: 'lp'),
        ),
        isFalse,
      );
    });

    test('a non-empty types set rejects other types', () {
      expect(
        hp.matches(
          _item('r', EquipmentType.regulator, key: 'hose_type', text: 'hp'),
        ),
        isFalse,
      );
    });

    test('choices are ORed', () {
      const either = EquipmentAttrCondition(
        key: 'hose_type',
        choices: {'hp', 'lpi'},
      );
      expect(
        either.matches(
          _item('a', EquipmentType.hose, key: 'hose_type', text: 'lpi'),
        ),
        isTrue,
      );
      expect(
        either.matches(
          _item('b', EquipmentType.hose, key: 'hose_type', text: 'lp'),
        ),
        isFalse,
      );
    });

    test('min and max bound the number; a missing number fails a bound', () {
      final c = EquipmentAttrCondition.suitThickness(min: 4, max: 6);
      expect(
        c.matches(
          _item('s', EquipmentType.wetsuit, key: 'thickness_mm', num: 5),
        ),
        isTrue,
      );
      expect(
        c.matches(
          _item('s', EquipmentType.wetsuit, key: 'thickness_mm', num: 7),
        ),
        isFalse,
      );
      expect(
        c.matches(
          _item('s', EquipmentType.wetsuit, key: 'thickness_mm', text: 'thin'),
        ),
        isFalse,
      );
    });

    test('suit thickness never matches a hood', () {
      final c = EquipmentAttrCondition.suitThickness(min: 1);
      expect(
        c.matches(_item('h', EquipmentType.hood, key: 'thickness_mm', num: 5)),
        isFalse,
      );
      expect(
        c.matches(
          _item('d', EquipmentType.drysuit, key: 'thickness_mm', num: 5),
        ),
        isTrue,
      );
    });

    test('a key-only condition means "has this attribute"', () {
      const c = EquipmentAttrCondition(key: 'hose_type');
      expect(
        c.matches(_item('h', EquipmentType.hose, key: 'hose_type', text: 'lp')),
        isTrue,
      );
      expect(c.matches(_item('h', EquipmentType.hose)), isFalse);
    });

    test('custom fields never match, even with the same key', () {
      const c = EquipmentAttrCondition(key: 'hose_type', choices: {'hp'});
      expect(
        c.matches(
          _item(
            'h',
            EquipmentType.hose,
            key: 'hose_type',
            text: 'hp',
            custom: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('equality', () {
    test('conditions compare by value, sets as sets', () {
      const a = EquipmentAttrCondition(
        key: 'k',
        choices: {'x', 'y'},
        types: {EquipmentType.hose},
      );
      // A distinct instance: its set literal lists the choices in the other
      // order, so equality has to come from comparing the sets.
      const b = EquipmentAttrCondition(
        key: 'k',
        choices: {'y', 'x'},
        types: {EquipmentType.hose},
      );
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const EquipmentAttrCondition(key: 'k', choices: {'x'})));
    });

    test('isSuitThickness recognises only the suit condition', () {
      expect(
        EquipmentAttrCondition.suitThickness(min: 3).isSuitThickness,
        isTrue,
      );
      expect(
        const EquipmentAttrCondition(key: 'thickness_mm').isSuitThickness,
        isFalse,
      );
    });

    test('the list key compares element by element', () {
      final one = EquipmentAttrConditionsKey([
        EquipmentAttrCondition.suitThickness(min: 3),
      ]);
      final two = EquipmentAttrConditionsKey([
        EquipmentAttrCondition.suitThickness(min: 3),
      ]);
      expect(one, two);
      expect(one.hashCode, two.hashCode);
      expect(
        one,
        isNot(
          EquipmentAttrConditionsKey([
            EquipmentAttrCondition.suitThickness(min: 4),
          ]),
        ),
      );
    });
  });
}
