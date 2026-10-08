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

    test('matches a file-imported computer that carries its whole name as '
        'the model to gear that splits brand and model (#2299)', () {
      // A file names the device in one string ("Shearwater Teric") with no
      // manufacturer, while its gear row carries brand "Shearwater" and
      // model "Teric". Field-by-field they never agree.
      final match = matchGearTwin(
        manufacturer: null,
        model: 'Shearwater Teric',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Teric',
          ),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('matches on model alone when the computer names no brand', () {
      // The same allowance matchImportedComputer makes: a file that says
      // only "Teric" did not name a brand, it did not name a different one.
      final match = matchGearTwin(
        manufacturer: null,
        model: 'Teric',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Teric',
          ),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('matches gear whose model already repeats its brand', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Teric',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Shearwater Teric',
          ),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('the combined name never matches a different brand', () {
      final match = matchGearTwin(
        manufacturer: null,
        model: 'Shearwater Teric',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', brand: 'Suunto', model: 'Teric'),
        ],
      );
      expect(match, isNull);
    });

    test('an exact brand and model match wins over a combined-name one', () {
      // The combined-name tier is a fallback. A computer that already had a
      // single exact twin must keep adopting it, not turn ambiguous because a
      // second row spells the same device another way.
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Teric',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', model: 'Shearwater Teric'),
          candidate(
            'gear-2',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Teric',
          ),
        ],
      );
      expect(match?.id, 'gear-2');
    });

    test('returns null when two combined-name candidates match', () {
      final match = matchGearTwin(
        manufacturer: null,
        model: 'Shearwater Teric',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate(
            'gear-1',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Teric',
          ),
          candidate(
            'gear-2',
            diverId: 'd1',
            brand: 'Shearwater',
            model: 'Shearwater Teric',
          ),
        ],
      );
      expect(match, isNull);
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
