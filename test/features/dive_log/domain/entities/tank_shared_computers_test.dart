import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';

void main() {
  group('decodeSharedComputerIds', () {
    test('null and blank text read as never recorded', () {
      expect(decodeSharedComputerIds(null), isNull);
      expect(decodeSharedComputerIds(''), isNull);
      expect(decodeSharedComputerIds('   '), isNull);
    });

    test('an empty array reads as recorded with nobody, not as never '
        'recorded', () {
      expect(decodeSharedComputerIds(noSharedComputersRecorded), isEmpty);
      expect(decodeSharedComputerIds(noSharedComputersRecorded), isNotNull);
    });

    test('reads a JSON array of computer ids', () {
      expect(decodeSharedComputerIds('["garmin","ocean"]'), [
        'garmin',
        'ocean',
      ]);
    });

    test('text that is not JSON reads as never recorded', () {
      expect(decodeSharedComputerIds('garmin'), isNull);
    });

    test('JSON that is not an array reads as never recorded', () {
      expect(decodeSharedComputerIds('{"id":"garmin"}'), isNull);
    });

    test('non-string entries are skipped', () {
      expect(decodeSharedComputerIds('["garmin",7,null]'), ['garmin']);
    });
  });

  group('encodeSharedComputerIds', () {
    test('never recorded is stored as null', () {
      expect(encodeSharedComputerIds(null), isNull);
    });

    test('an empty list is stored as the recorded-with-nobody marker', () {
      expect(encodeSharedComputerIds(const []), noSharedComputersRecorded);
    });

    test('duplicates are stored once and the result round-trips', () {
      final encoded = encodeSharedComputerIds(['garmin', 'ocean', 'garmin']);
      expect(decodeSharedComputerIds(encoded), ['garmin', 'ocean']);
    });
  });

  group('DiveTank.isUsedBy', () {
    const owned = DiveTank(id: 't', computerId: 'suunto');

    test('a tank with nothing recorded is used by its owner only', () {
      expect(owned.isUsedBy('suunto'), isTrue);
      expect(owned.isUsedBy('garmin'), isFalse);
    });

    test('a computer the tank lists shares it', () {
      final shared = owned.copyWith(sharedComputerIds: ['garmin']);
      expect(shared.isUsedBy('garmin'), isTrue);
    });
  });
}
