import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';

/// Matching gear to the catalogue and comparing versions (issue #5104). An
/// update is claimed only when the installed version is found in the list
/// below a newer release; release order, never version parsing, decides.
void main() {
  late FirmwareCatalogue catalogue;
  late FirmwareModel perdix;

  setUpAll(() {
    catalogue = FirmwareCatalogue.parse(
      File(
        p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
      ).readAsStringSync(),
    )!;
    perdix = catalogue.models.first;
  });

  FirmwareStatus statusOf(
    String? installed, {
    String? brand = 'Shearwater',
    String? model = 'Perdix 2',
    EquipmentType type = EquipmentType.computer,
  }) => firmwareStatusFor(
    catalogue: catalogue,
    type: type,
    brand: brand,
    model: model,
    installedVersion: installed,
  );

  group('normalizeFirmwareName', () {
    test('drops case, spaces and punctuation', () {
      expect(normalizeFirmwareName(' Perdix-2 AI '), 'perdix2ai');
      expect(normalizeFirmwareName('OSTC 4'), 'ostc4');
    });
  });

  group('matchFirmwareModel', () {
    test('matches across spelling and maker aliases', () {
      FirmwareModel? match(String brand, String model) => matchFirmwareModel(
        catalogue,
        type: EquipmentType.computer,
        brand: brand,
        model: model,
      );
      expect(match('shearwater research', 'perdix2'), perdix);
      expect(match('Shearwater', 'Perdix 2'), perdix);
      expect(match('SHEARWATER', 'perdix-2'), perdix);
    });

    test('the equipment type narrows the match', () {
      expect(
        matchFirmwareModel(
          catalogue,
          type: EquipmentType.light,
          brand: 'Shearwater',
          model: 'Perdix 2',
        ),
        isNull,
      );
    });

    test('the maker must match', () {
      expect(
        matchFirmwareModel(
          catalogue,
          type: EquipmentType.computer,
          brand: 'Suunto',
          model: 'Perdix 2',
        ),
        isNull,
      );
      expect(
        matchFirmwareModel(
          catalogue,
          type: EquipmentType.computer,
          brand: null,
          model: 'Perdix 2',
        ),
        isNull,
      );
      expect(
        matchFirmwareModel(
          catalogue,
          type: EquipmentType.computer,
          brand: 'Shearwater',
          model: '  ',
        ),
        isNull,
      );
    });
  });

  group('releaseIndexOf', () {
    test('finds a version by its own or a reported spelling', () {
      expect(releaseIndexOf(perdix, 'V95'), 0);
      expect(releaseIndexOf(perdix, ' v94 '), 1);
      expect(releaseIndexOf(perdix, '92'), 2);
      expect(releaseIndexOf(perdix, 'V90'), isNull);
    });
  });

  group('firmwareStatusFor', () {
    test('the newest release is up to date', () {
      expect(statusOf('V95'), isA<FirmwareUpToDate>());
    });

    test('an older listed release has the newer ones above it', () {
      final status = statusOf('92');
      expect(status, isA<FirmwareUpdateAvailable>());
      status as FirmwareUpdateAvailable;
      expect(status.newer.map((r) => r.version), ['V95', 'V94']);
      expect(status.latest.version, 'V95');
    });

    test('a version not in the list is never an update', () {
      final status = statusOf('V90');
      expect(status, isA<FirmwareUnknownVersion>());
      expect((status as FirmwareUnknownVersion).latest.version, 'V95');
    });

    test('no recorded version invites the diver to record one', () {
      expect(statusOf(null), isA<FirmwareNoVersion>());
      expect(statusOf('  '), isA<FirmwareNoVersion>());
      expect((statusOf(null) as FirmwareNoVersion).latest.version, 'V95');
    });

    test('unmatched gear is not listed', () {
      expect(statusOf('V95', brand: 'Suunto'), isA<FirmwareNotListed>());
      expect(
        firmwareStatusFor(
          catalogue: null,
          type: EquipmentType.computer,
          brand: 'Shearwater',
          model: 'Perdix 2',
          installedVersion: 'V92',
        ),
        isA<FirmwareNotListed>(),
      );
    });
  });

  group('sameFirmwareRelease', () {
    test('two spellings of one release are the same', () {
      expect(sameFirmwareRelease('V95', '95', model: perdix), isTrue);
      expect(sameFirmwareRelease('v95', 'V95'), isTrue);
    });

    test('different releases, or unknown spellings, are not', () {
      expect(sameFirmwareRelease('V95', 'V94', model: perdix), isFalse);
      expect(sameFirmwareRelease('V95', '95'), isFalse);
      expect(sameFirmwareRelease('V90', '90', model: perdix), isFalse);
    });
  });
}
