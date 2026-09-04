import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';

import 'package:submersion/features/universal_import/data/services/macdive_value_mapper.dart';

void main() {
  group('MacDiveValueMapper.waterType', () {
    test('maps saltwater strings', () {
      expect(MacDiveValueMapper.waterType('saltwater'), isNotNull);
      expect(MacDiveValueMapper.waterType('Salt'), isNotNull);
      expect(MacDiveValueMapper.waterType('sea'), isNotNull);
      expect(MacDiveValueMapper.waterType('Ocean'), isNotNull);
    });

    test('maps freshwater strings', () {
      expect(MacDiveValueMapper.waterType('freshwater'), isNotNull);
      expect(MacDiveValueMapper.waterType('Fresh'), isNotNull);
      expect(MacDiveValueMapper.waterType('lake'), isNotNull);
      expect(MacDiveValueMapper.waterType('river'), isNotNull);
    });

    test('maps brackish strings', () {
      expect(MacDiveValueMapper.waterType('brackish'), isNotNull);
      expect(MacDiveValueMapper.waterType('Brackish'), isNotNull);
    });

    test('returns null for unknown or empty', () {
      expect(MacDiveValueMapper.waterType('swamp'), isNull);
      expect(MacDiveValueMapper.waterType(null), isNull);
      expect(MacDiveValueMapper.waterType(''), isNull);
      expect(MacDiveValueMapper.waterType('   '), isNull);
    });
  });

  group('MacDiveValueMapper.entryType', () {
    test('maps boat and related entries', () {
      expect(MacDiveValueMapper.entryType('boat'), isNotNull);
      expect(MacDiveValueMapper.entryType('Boat'), isNotNull);
      expect(MacDiveValueMapper.entryType('liveaboard'), isNotNull);
    });

    test('maps shore and related entries', () {
      expect(MacDiveValueMapper.entryType('shore'), isNotNull);
      expect(MacDiveValueMapper.entryType('beach'), isNotNull);
      expect(MacDiveValueMapper.entryType('Shore'), isNotNull);
    });

    test('maps back roll entries', () {
      expect(MacDiveValueMapper.entryType('back roll'), isNotNull);
      expect(MacDiveValueMapper.entryType('backroll'), isNotNull);
      expect(MacDiveValueMapper.entryType('Back Roll'), isNotNull);
    });

    test('maps giant stride entries', () {
      expect(MacDiveValueMapper.entryType('giant stride'), isNotNull);
      expect(MacDiveValueMapper.entryType('giantstride'), isNotNull);
      expect(MacDiveValueMapper.entryType('Giant Stride'), isNotNull);
    });

    test('returns null for unknown or empty', () {
      expect(MacDiveValueMapper.entryType(null), isNull);
      expect(MacDiveValueMapper.entryType(''), isNull);
      expect(MacDiveValueMapper.entryType('   '), isNull);
      expect(MacDiveValueMapper.entryType('cave'), isNull);
    });
  });

  group('MacDiveValueMapper.rating', () {
    test('rounds fractional ratings', () {
      expect(MacDiveValueMapper.rating(3.2), 3);
      expect(MacDiveValueMapper.rating(4.7), 5);
      expect(MacDiveValueMapper.rating(2.5), 3);
    });

    test('clamps out-of-range', () {
      expect(MacDiveValueMapper.rating(-1.0), 0);
      expect(MacDiveValueMapper.rating(7.5), 5);
      expect(MacDiveValueMapper.rating(0.0), 0);
      expect(MacDiveValueMapper.rating(5.0), 5);
    });

    test('null passes through', () {
      expect(MacDiveValueMapper.rating(null), isNull);
    });
  });

  group('MacDiveValueMapper.normalizeDiveType', () {
    test('trims whitespace', () {
      expect(
        MacDiveValueMapper.normalizeDiveType('  Recreational  '),
        'Recreational',
      );
      expect(MacDiveValueMapper.normalizeDiveType('\tNight\n'), 'Night');
    });

    test('passes through arbitrary strings', () {
      expect(MacDiveValueMapper.normalizeDiveType('Night'), 'Night');
      expect(MacDiveValueMapper.normalizeDiveType('Cave'), 'Cave');
      expect(
        MacDiveValueMapper.normalizeDiveType('custom-dive-type'),
        'custom-dive-type',
      );
    });
  });

  group('MacDiveValueMapper.equipmentType', () {
    // MacDive's type field is free text, so real libraries carry values that
    // match no enum name. Before this mapping nearly everything imported as
    // `other` (#912).
    const cases = <String, EquipmentType>{
      'Regulator': EquipmentType.regulator,
      'Reg - Longhose': EquipmentType.regulator,
      'reg': EquipmentType.regulator,
      'Octopus': EquipmentType.regulator,
      'Second Stage': EquipmentType.regulator,
      'First stage': EquipmentType.regulator,
      'BCD': EquipmentType.bcd,
      'BCD - Wing': EquipmentType.bcd,
      'bc': EquipmentType.bcd,
      'Wing': EquipmentType.bcd,
      'Backplate and harness': EquipmentType.bcd,
      'Computer': EquipmentType.computer,
      'Dive Watch': EquipmentType.computer,
      'Transmitter': EquipmentType.transmitter,
      'Wetsuit': EquipmentType.wetsuit,
      'wet suit 5mm': EquipmentType.wetsuit,
      'Drysuit': EquipmentType.drysuit,
      'Dry Suit': EquipmentType.drysuit,
      'Rebreather': EquipmentType.rebreather,
      'CCR unit': EquipmentType.rebreather,
      'Tank': EquipmentType.tank,
      'Cylinder': EquipmentType.tank,
      'Weights': EquipmentType.weights,
      'Ballast': EquipmentType.weights,
      'Fins': EquipmentType.fins,
      'Mask': EquipmentType.mask,
      'Hood': EquipmentType.hood,
      'Gloves': EquipmentType.gloves,
      'Boots': EquipmentType.boots,
      'Light': EquipmentType.light,
      'Torch': EquipmentType.light,
      'Camera': EquipmentType.camera,
      'Strobe': EquipmentType.camera,
      'SMB': EquipmentType.smb,
      'DSMB': EquipmentType.smb,
      'Reel': EquipmentType.reel,
      'Spool': EquipmentType.reel,
      'Knife': EquipmentType.knife,
      'Shears': EquipmentType.knife,
      'DPV': EquipmentType.dpv,
      'Scooter': EquipmentType.dpv,
      'Suex XJoy Scooter': EquipmentType.dpv,
      'Diver Propulsion Vehicle': EquipmentType.dpv,
      // #1518 types. MacDive's field is free text, so these are the words
      // real libraries actually contain.
      'Undergarment': EquipmentType.undergarment,
      'Santi BZ400 Undersuit': EquipmentType.undergarment,
      'Rash Guard': EquipmentType.rashGuard,
      'Lycra top': EquipmentType.rashGuard,
      'Snorkel': EquipmentType.snorkel,
      'Compass': EquipmentType.compass,
      'SPG': EquipmentType.instrument,
      'Depth Gauge': EquipmentType.instrument,
      'Bottom Timer': EquipmentType.instrument,
      'O2 Analyzer': EquipmentType.instrument,
      'Save-a-dive kit': EquipmentType.tool,
      'Torque wrench': EquipmentType.tool,
      'O-ring kit': EquipmentType.tool,
    };

    cases.forEach((input, expected) {
      test('maps "$input" to ${expected.name}', () {
        expect(MacDiveValueMapper.equipmentType(input), expected);
      });
    });

    test('is case- and whitespace-insensitive', () {
      expect(
        MacDiveValueMapper.equipmentType('  WETSUIT  '),
        EquipmentType.wetsuit,
      );
    });

    test('a console computer stays a computer', () {
      // The instrument family matches "console", so it has to be tried after
      // the computer check or every console-mounted computer would import as
      // a gauge.
      expect(
        MacDiveValueMapper.equipmentType('Console Computer'),
        EquipmentType.computer,
      );
      expect(
        MacDiveValueMapper.equipmentType('Compass console'),
        EquipmentType.compass,
      );
    });

    test('a bare "thermal" is left alone', () {
      // Plenty of divers label a wetsuit "3mm thermal", so the undergarment
      // match is deliberately narrow: it must not pull suits into the liner
      // bucket.
      expect(
        MacDiveValueMapper.equipmentType('3mm Thermal'),
        EquipmentType.other,
      );
    });

    test('prefers the more specific suit', () {
      // "drysuit" contains no "wetsuit", but both contain "suit" - order
      // matters, so pin it.
      expect(
        MacDiveValueMapper.equipmentType('Drysuit'),
        EquipmentType.drysuit,
      );
      expect(
        MacDiveValueMapper.equipmentType('Wetsuit'),
        EquipmentType.wetsuit,
      );
    });

    test('falls back to other for an unrecognised label', () {
      expect(
        MacDiveValueMapper.equipmentType('Lucky Hat'),
        EquipmentType.other,
      );
      expect(MacDiveValueMapper.equipmentType('Other'), EquipmentType.other);
    });

    test('returns null for empty input so the importer keeps its default', () {
      expect(MacDiveValueMapper.equipmentType(null), isNull);
      expect(MacDiveValueMapper.equipmentType(''), isNull);
      expect(MacDiveValueMapper.equipmentType('   '), isNull);
    });
  });
}
