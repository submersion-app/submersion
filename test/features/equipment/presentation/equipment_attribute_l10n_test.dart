import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('every catalog key has a localized label', () {
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        final label = attributeLabel(l10n, def.key);
        expect(label, isNotEmpty);
        expect(
          label,
          isNot(def.key),
          reason: 'attrLabel missing for ${def.key}',
        );
      }
    }
  });

  test('every choice option has a localized label', () {
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        for (final option in def.choiceKeys) {
          final label = attributeChoiceLabel(l10n, def.key, option);
          expect(label, isNotEmpty);
          expect(
            label,
            isNot(option),
            reason: 'attrChoice missing for ${def.key}/$option',
          );
        }
      }
    }
  });

  test('unknown keys fall back to the raw key (custom fields)', () {
    expect(attributeLabel(l10n, 'my_custom_field'), 'my_custom_field');
    expect(attributeChoiceLabel(l10n, 'foo', 'bar'), 'bar');
  });
}
