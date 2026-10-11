import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/computer_serial_identity.dart';

void main() {
  group('isShearwaterFamily', () {
    test('manufacturer Shearwater', () {
      expect(isShearwaterFamily(manufacturer: ' shearwater '), isTrue);
    });

    test('model alone, with or without the brand prefix', () {
      expect(isShearwaterFamily(model: 'Perdix 2'), isTrue);
      expect(isShearwaterFamily(model: 'Shearwater Teric'), isTrue);
      expect(isShearwaterFamily(model: 'NERD 2'), isTrue);
      expect(isShearwaterFamily(model: 'Peregrine TX'), isTrue);
    });

    test('other brands are not', () {
      expect(
        isShearwaterFamily(manufacturer: 'Garmin', model: 'Descent Mk3'),
        isFalse,
      );
      expect(isShearwaterFamily(model: 'Petrelli 9'), isFalse);
      expect(isShearwaterFamily(), isFalse);
    });
  });

  group('computerSerialsMatch', () {
    test('Shearwater hex equals its decimal both ways', () {
      // 0xA1B2C3D4 == 2712847316
      expect(
        computerSerialsMatch('A1B2C3D4', '2712847316', shearwater: true),
        isTrue,
      );
      expect(
        computerSerialsMatch('2712847316', 'a1b2c3d4', shearwater: true),
        isTrue,
      );
    });

    test('hex with leading zeros', () {
      // 0x00BC614E == 12345678
      expect(
        computerSerialsMatch('00BC614E', '12345678', shearwater: true),
        isTrue,
      );
    });

    test('different Shearwater serials do not match', () {
      expect(
        computerSerialsMatch('A1B2C3D4', '2712847317', shearwater: true),
        isFalse,
      );
    });

    test('non-Shearwater serials compare as text only', () {
      expect(
        computerSerialsMatch('00BC614E', '12345678', shearwater: false),
        isFalse,
      );
      expect(
        computerSerialsMatch(' ab 12 ', 'AB 12', shearwater: false),
        isTrue,
      );
    });

    test('blank never matches', () {
      expect(computerSerialsMatch('', '', shearwater: true), isFalse);
      expect(computerSerialsMatch(null, '1', shearwater: false), isFalse);
    });

    test('decimal above 32 bits gets no hex key', () {
      expect(serialMatchKeys('4294967296', shearwater: true), {'4294967296'});
    });
  });

  group('shearwaterPair', () {
    test('true when either side is Shearwater', () {
      expect(
        shearwaterPair(modelA: 'Perdix 2', manufacturerB: 'Shearwater'),
        isTrue,
      );
      expect(shearwaterPair(modelA: 'Perdix 2'), isTrue);
      expect(shearwaterPair(modelA: 'D5', manufacturerB: 'Suunto'), isFalse);
      // A side that names another family is not a Shearwater serial in
      // the other radix, whatever the first side is.
      expect(
        shearwaterPair(
          modelA: 'Perdix 2',
          manufacturerB: 'Suunto',
          modelB: 'D5',
        ),
        isFalse,
      );
    });
  });

  group('canonicalDownloadedSerial', () {
    test('Shearwater decimal becomes 8-char uppercase hex', () {
      expect(
        canonicalDownloadedSerial(
          vendor: 'Shearwater',
          product: 'Perdix 2',
          serial: '2712847316',
        ),
        'A1B2C3D4',
      );
      expect(
        canonicalDownloadedSerial(
          vendor: 'Shearwater',
          product: 'Petrel 3',
          serial: '12345678',
        ),
        '00BC614E',
      );
    });

    test('other vendors pass through trimmed', () {
      expect(
        canonicalDownloadedSerial(
          vendor: 'Ratio',
          product: 'iX3M 2',
          serial: ' 74691 ',
        ),
        '74691',
      );
    });

    test('blank is null; non-numeric Shearwater is uppercased', () {
      expect(
        canonicalDownloadedSerial(vendor: 'Shearwater', serial: '  '),
        isNull,
      );
      expect(
        canonicalDownloadedSerial(vendor: 'Shearwater', serial: 'a1b2c3d4'),
        'A1B2C3D4',
      );
    });
  });

  group('isAllDigitsSerial', () {
    test('is true only for a serial made of digits alone', () {
      expect(isAllDigitsSerial('12345678'), isTrue);
      expect(isAllDigitsSerial('2712847316'), isTrue);
      expect(isAllDigitsSerial('A1B2C3D4'), isFalse);
      expect(isAllDigitsSerial('1234 5678'), isFalse);
      expect(isAllDigitsSerial(''), isFalse);
    });
  });
}
