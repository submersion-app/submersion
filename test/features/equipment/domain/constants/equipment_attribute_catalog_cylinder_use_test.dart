import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A cylinder's equipment record can say it is a suit inflation bottle
/// (issue #4243).
void main() {
  test('a tank carries a Cylinder use choice', () {
    final def = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.tank,
    ).singleWhere((d) => d.key == EquipmentAttrKeys.cylinderUse);

    expect(EquipmentAttrKeys.cylinderUse, 'cylinder_use');
    expect(def.kind, AttributeKind.choice);
    expect(def.choiceKeys, ['breathing_gas', 'suit_inflation']);
  });

  test('the field and its choices are named in English', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(attributeLabel(l10n, 'cylinder_use'), 'Cylinder use');
    expect(
      attributeChoiceLabel(l10n, 'cylinder_use', 'breathing_gas'),
      'Breathing gas',
    );
    expect(
      attributeChoiceLabel(l10n, 'cylinder_use', 'suit_inflation'),
      'Suit inflation',
    );
  });

  test('isSuitInflationCylinder reads the choice, unset is breathing', () {
    EquipmentItem tank(String? use) => EquipmentItem(
      id: 'c1',
      name: 'Argon 0.85',
      type: EquipmentType.tank,
      attributes: [
        if (use != null)
          EquipmentAttribute.curated(
            equipmentId: 'c1',
            key: 'cylinder_use',
            valueText: use,
          ),
      ],
    );

    expect(tank('suit_inflation').isSuitInflationCylinder, isTrue);
    expect(tank('breathing_gas').isSuitInflationCylinder, isFalse);
    expect(tank(null).isSuitInflationCylinder, isFalse);
  });
}
