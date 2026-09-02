import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/dive_computer_gear_identity.dart';

GearTwinCandidate candidate(
  String id, {
  String? diverId,
  String? brand,
  String? model,
  String? serialNumber,
}) => GearTwinCandidate(
  id: id,
  diverId: diverId,
  brand: brand,
  model: model,
  serialNumber: serialNumber,
);

void main() {
  group('diveComputerGearId', () {
    test('is stable for the same computer id', () {
      expect(diveComputerGearId('comp-1'), diveComputerGearId('comp-1'));
    });

    test('differs between computers', () {
      expect(diveComputerGearId('comp-1'), isNot(diveComputerGearId('comp-2')));
    });

    test('is a v5 uuid, so every device derives the same primary key', () {
      // Version nibble of a v5 uuid is the first character of group three.
      expect(diveComputerGearId('comp-1').split('-')[2][0], '5');
    });
  });

  group('matchGearTwin', () {
    test('matches on serial when the computer has one', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'ABC123',
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', serialNumber: 'abc123'),
          candidate('gear-2', diverId: 'd1', serialNumber: 'ZZZ999'),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('falls back to brand and model when the serial is null', () {
      // libdivecomputer leaves the serial null for many devices (#1064), so a
      // serial-only rule would be dead for a large share of users.
      final match = matchGearTwin(
        manufacturer: '  SHEARWATER ',
        model: 'Perdix   2',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Perdix 2',
          ),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('returns null when two candidates match, rather than guessing', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Perdix 2',
          ),
          candidate(
            'gear-2',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Perdix 2',
          ),
        ],
      );
      expect(match, isNull);
    });

    test('returns null when nothing matches', () {
      final match = matchGearTwin(
        manufacturer: 'Suunto',
        model: 'EON Core',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Perdix 2',
          ),
        ],
      );
      expect(match, isNull);
    });

    test('never crosses diver scopes', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'ABC123',
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd2', serialNumber: 'ABC123'),
        ],
      );
      expect(match, isNull);
    });

    test('matches null-diver candidates to a null-diver computer', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'ABC123',
        diverId: null,
        candidates: [candidate('gear-1', serialNumber: 'ABC123')],
      );
      expect(match?.id, 'gear-1');
    });

    test('returns null when the computer has neither serial nor model', () {
      final match = matchGearTwin(
        manufacturer: null,
        model: null,
        serialNumber: null,
        diverId: 'd1',
        candidates: [candidate('gear-1', diverId: 'd1')],
      );
      expect(match, isNull);
    });
  });
}
