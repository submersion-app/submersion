import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/universal_import/data/services/divelogs_reference_mappers.dart';

void main() {
  group('equipmentTypeForGeartypeName', () {
    test('maps English and German geartype names', () {
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Regulator'),
        EquipmentType.regulator,
      );
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Atemregler'),
        EquipmentType.regulator,
      );
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Jacket'),
        EquipmentType.bcd,
      );
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Flossen'),
        EquipmentType.fins,
      );
    });

    test('drysuit wins over wetsuit for suit names', () {
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName(
          'Trockentauchanzug',
        ),
        EquipmentType.drysuit,
      );
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Nassanzug'),
        EquipmentType.wetsuit,
      );
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Drysuit'),
        EquipmentType.drysuit,
      );
    });

    test('maps bag geartypes, but not a lift bag or a weight pouch', () {
      // #2952. The German "Tasche" also names a pocket, so the lead pouch's
      // "Blei" must still win over it.
      const cases = {
        'Bag': EquipmentType.bag,
        'Tasche': EquipmentType.bag,
        'Tauchtasche': EquipmentType.bag,
        'Bleitasche': EquipmentType.weights,
        // German for a flashlight; the light row must stay above the bag's.
        'Taschenlampe': EquipmentType.light,
        'Lift bag': EquipmentType.smb,
        'Lift-bag': EquipmentType.smb,
        'Liftbag': EquipmentType.smb,
        'Lifting bag': EquipmentType.smb,
        'Salvage bag': EquipmentType.smb,
        'Hebesack': EquipmentType.smb,
        // A counterlung, not luggage.
        'Breathing bag': EquipmentType.other,
        'Breathing-bag': EquipmentType.other,
        'Breathingbag': EquipmentType.other,
      };
      cases.forEach((input, expected) {
        expect(
          DivelogsReferenceMappers.equipmentTypeForGeartypeName(input),
          expected,
          reason: input,
        );
      });
    });

    test('unknown or null names map to other', () {
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName('Gadget'),
        EquipmentType.other,
      );
      expect(
        DivelogsReferenceMappers.equipmentTypeForGeartypeName(null),
        EquipmentType.other,
      );
    });
  });

  group('agencyForOrg', () {
    test('matches enum names case-insensitively', () {
      expect(
        DivelogsReferenceMappers.agencyForOrg('PADI'),
        CertificationAgency.padi,
      );
      expect(
        DivelogsReferenceMappers.agencyForOrg('ssi '),
        CertificationAgency.ssi,
      );
    });

    test('unknown or null orgs map to other', () {
      expect(
        DivelogsReferenceMappers.agencyForOrg('Some Club'),
        CertificationAgency.other,
      );
      expect(
        DivelogsReferenceMappers.agencyForOrg(null),
        CertificationAgency.other,
      );
    });
  });

  group('levelForName', () {
    test('matches display names case-insensitively', () {
      expect(
        DivelogsReferenceMappers.levelForName('Open Water'),
        CertificationLevel.openWater,
      );
      expect(
        DivelogsReferenceMappers.levelForName('open water'),
        CertificationLevel.openWater,
      );
    });

    test('unrecognized names return null', () {
      expect(
        DivelogsReferenceMappers.levelForName('Fancy Specialty XYZ'),
        isNull,
      );
    });
  });
}
