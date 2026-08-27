import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divelogs_sync/data/mappers/divelogs_reference_mappers.dart';

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

  group('geartypeIdForEquipmentType', () {
    test('finds the first remote geartype mapping to the type', () {
      expect(
        DivelogsReferenceMappers.geartypeIdForEquipmentType(EquipmentType.bcd, {
          1: 'Regulator',
          2: 'Jacket',
        }),
        2,
      );
    });

    test('returns null when nothing maps', () {
      expect(
        DivelogsReferenceMappers.geartypeIdForEquipmentType(
          EquipmentType.camera,
          {1: 'Regulator'},
        ),
        isNull,
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
