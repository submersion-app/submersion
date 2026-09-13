import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';

import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/universal_import/data/services/suit_classifier.dart';

void main() {
  void expectSuit(String text, EquipmentType type, [String? thickness]) {
    final result = classifySuit(text);
    expect(result, isNotNull, reason: '"$text" should classify');
    expect(result!.type, type, reason: '"$text" type');
    expect(result.thickness, thickness, reason: '"$text" thickness');
  }

  void expectUnclear(String? text) {
    expect(classifySuit(text), isNull, reason: '"$text" should stay unclear');
  }

  group('classifySuit wetsuits', () {
    test('names that say wetsuit', () {
      expectSuit('Wetsuit', EquipmentType.wetsuit);
      expectSuit('wet suit', EquipmentType.wetsuit);
      expectSuit('Wet', EquipmentType.wetsuit);
    });

    test('a thickness token alone marks a wetsuit and is recorded', () {
      expectSuit('Bare 7mm', EquipmentType.wetsuit, '7mm');
      expectSuit('5/4 full', EquipmentType.wetsuit, '5/4');
      expectSuit('7/5/3', EquipmentType.wetsuit, '7/5/3');
      expectSuit('Xcel 5/4mm', EquipmentType.wetsuit, '5/4mm');
      expectSuit('6.5 mm', EquipmentType.wetsuit, '6.5 mm');
    });

    test('a thickness beside the word wetsuit is recorded', () {
      expectSuit('3mm Bare wetsuit', EquipmentType.wetsuit, '3mm');
      expectSuit('Wetsuit 7mm', EquipmentType.wetsuit, '7mm');
    });

    test(
      'the recorded token is lowercased so it stays a valid designation',
      () {
        expectSuit('BARE 7MM', EquipmentType.wetsuit, '7mm');
      },
    );

    test('a shorty is a wetsuit', () {
      expectSuit('Shorty', EquipmentType.wetsuit);
      expectSuit('3mm shortie', EquipmentType.wetsuit, '3mm');
    });

    test('a semi-dry is a wetsuit, not a drysuit', () {
      expectSuit('Semi-dry 7mm', EquipmentType.wetsuit, '7mm');
      expectSuit('Semidry', EquipmentType.wetsuit);
      expectSuit('semi dry suit', EquipmentType.wetsuit);
    });
  });

  group('classifySuit drysuits', () {
    test('names that say dry', () {
      expectSuit('Drysuit', EquipmentType.drysuit);
      expectSuit('Dry suit', EquipmentType.drysuit);
      expectSuit('dry-suit', EquipmentType.drysuit);
      expectSuit('DUI dry', EquipmentType.drysuit);
    });

    test('a neoprene drysuit is a drysuit and records no thickness', () {
      expectSuit('4mm neoprene drysuit', EquipmentType.drysuit);
    });

    test('membrane and trilaminate suits are drysuits', () {
      expectSuit('Membrane', EquipmentType.drysuit);
      expectSuit('Trilaminate', EquipmentType.drysuit);
      expectSuit('Trilam shell', EquipmentType.drysuit);
    });
  });

  group('classifySuit unclear text stays unclear', () {
    test('empty input', () {
      expectUnclear(null);
      expectUnclear('');
      expectUnclear('   ');
    });

    test('garments worn under or instead of a suit', () {
      expectUnclear('Dry undersuit');
      expectUnclear('Thermal undergarment');
      expectUnclear('Base layer');
      expectUnclear('Rash guard');
      expectUnclear('Skin suit');
    });

    test('both wet and dry named', () {
      expectUnclear('Wet/dry combo');
    });

    test('words that are ambiguous between wetsuit and drysuit', () {
      expectUnclear('Full suit');
      expectUnclear('Neoprene');
      expectUnclear('Vest');
      expectUnclear('Jacket');
    });

    test('dry or wet inside another word does not count', () {
      expectUnclear('Sundry');
      expectUnclear('Laundry bag');
      expectUnclear('Dryrobe');
      expectUnclear('Wetnotes');
    });

    test('a dry or wet accessory is not a suit', () {
      expectUnclear('Dry gloves');
      expectUnclear('Wet hood');
      expectSuit('Drysuit, dry gloves', EquipmentType.drysuit);
      expectSuit('Wet suit + hood', EquipmentType.wetsuit);
    });

    test('a bare number is not a thickness', () {
      expectUnclear('Bare 5');
      expectUnclear('Size 10');
    });

    test('a thickness beside an accessory is not a suit', () {
      expectUnclear('5mm hood');
      expectUnclear('3mm gloves');
      expectUnclear('7mm boots');
      expectUnclear('2mm vest');
      expectUnclear('5mm hoodie');
      expectUnclear('3mm booties');
      expectUnclear('2mm mittens');
      expectUnclear('3mm socks');
    });

    test('a word that only starts like an accessory does not count', () {
      expectSuit('7mm hooded wetsuit', EquipmentType.wetsuit, '7mm');
      expectSuit('Hooded 7mm', EquipmentType.wetsuit, '7mm');
    });

    test('an out-of-range number is not a thickness', () {
      expectUnclear('20mm');
      expectUnclear('0mm');
      expectUnclear('12/05/2020');
    });
  });

  group('classifySuit thickness is recorded only when unambiguous', () {
    test('two different thicknesses keep the type and drop the thickness', () {
      expectSuit('3mm shorty over 5mm full', EquipmentType.wetsuit);
    });

    test('the same thickness repeated is still one thickness', () {
      expectSuit('7mm wetsuit (7mm)', EquipmentType.wetsuit, '7mm');
    });

    test('an accessory beside a wetsuit takes the thickness away', () {
      expectSuit('Wetsuit, 5mm hood', EquipmentType.wetsuit);
    });

    test('an out-of-range thickness beside a wetsuit is dropped', () {
      expectSuit('Wetsuit 20mm', EquipmentType.wetsuit);
    });

    test('a comma between two thicknesses still makes them two', () {
      expectSuit('Wetsuit 7mm, 3mm shorty', EquipmentType.wetsuit);
      expectSuit('Wetsuit 7mm, 5mm', EquipmentType.wetsuit);
      expectSuit('Wetsuit 7mm,3mm', EquipmentType.wetsuit);
      expectUnclear('7mm,3mm');
    });

    test('a decimal comma after a slash designation is not cut short', () {
      expectSuit('Wetsuit 5/4,5', EquipmentType.wetsuit);
    });

    test('punctuation after a single thickness keeps it', () {
      expectSuit('Wetsuit 7mm.', EquipmentType.wetsuit, '7mm');
      expectSuit('Bare 7mm, full', EquipmentType.wetsuit, '7mm');
    });

    test('a hyphenated designation is not read from its last panel', () {
      expectSuit('5-4mm wetsuit', EquipmentType.wetsuit);
      expectUnclear('7-5-3mm');
    });

    test('a decimal comma is not read as a thickness', () {
      expectSuit('Wetsuit 6,5mm', EquipmentType.wetsuit);
    });

    test('designations are thickest first, so a fraction is not one', () {
      expectSuit('4/3 wetsuit', EquipmentType.wetsuit, '4/3');
      expectSuit('3/2', EquipmentType.wetsuit, '3/2');
      expectSuit('1/4 inch wetsuit', EquipmentType.wetsuit);
      expectUnclear('1/4 zip');
      expectUnclear('3/4 length');
    });

    test('every recorded token is a designation the catalog accepts', () {
      const cases = {
        'Bare 7mm': 7.0,
        '5/4 full': 5.0,
        '7/5/3': 7.0,
        'Xcel 5mm/4mm': 5.0,
        '6.5 mm': 6.5,
        'BARE 7MM': 7.0,
      };
      for (final entry in cases.entries) {
        final thickness = classifySuit(entry.key)!.thickness!;
        expect(
          isValidThicknessDesignation(thickness),
          isTrue,
          reason: thickness,
        );
        expect(
          parsePrimaryThickness(thickness),
          entry.value,
          reason: thickness,
        );
      }
    });
  });
}
