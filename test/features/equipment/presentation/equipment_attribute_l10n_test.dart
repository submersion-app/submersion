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

  group('attributeHelperText (issue #4236)', () {
    test('the SKU is told apart from the serial number', () {
      expect(
        attributeHelperText(l10n, EquipmentAttrKeys.sku),
        l10n.attrHelper_sku,
      );
      expect(attributeHelperText(l10n, EquipmentAttrKeys.sku), isNotEmpty);
    });

    test('self-explanatory keys and custom fields carry none', () {
      expect(attributeHelperText(l10n, EquipmentAttrKeys.retailer), isNull);
      expect(attributeHelperText(l10n, EquipmentAttrKeys.productUrl), isNull);
      expect(attributeHelperText(l10n, 'my_custom_field'), isNull);
    });

    // The form shows a helper only on free-text inputs; the other kinds
    // build their own decoration or picker. A helper given to any other
    // kind would resolve here and never reach the diver.
    test('only free-text attributes carry a helper', () {
      for (final type in EquipmentType.values) {
        for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
          if (attributeHelperText(l10n, def.key) == null) continue;
          expect(
            def.kind,
            AttributeKind.text,
            reason: '${def.key} has a helper the form would not show',
          );
        }
      }
    });
  });

  test('the SKU label spells out the abbreviation (issue #4236)', () {
    final de = lookupAppLocalizations(const Locale('de'));
    expect(attributeLabel(de, EquipmentAttrKeys.sku), 'Artikelnummer (SKU)');
    expect(attributeLabel(l10n, EquipmentAttrKeys.sku), 'Product number (SKU)');
  });
}
