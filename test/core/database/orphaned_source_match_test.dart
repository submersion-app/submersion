import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/database/orphaned_source_match.dart';

void main() {
  ImportedComputerCandidate computer(
    String id, {
    String? manufacturer = 'Shearwater',
    String? model = 'Perdix',
    String? serial,
    String? diverId,
  }) => ImportedComputerCandidate(
    id: id,
    diverId: diverId,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serial,
  );

  OrphanedSource source(
    String id, {
    String diveId = 'dive-1',
    String? diverId,
    String? computerModel = 'Shearwater Perdix',
    String? serial,
    String? vendor,
    String? product,
  }) => OrphanedSource(
    id: id,
    diveId: diveId,
    diverId: diverId,
    computerModel: computerModel,
    computerSerial: serial,
    descriptorVendor: vendor,
    descriptorProduct: product,
  );

  group('sourceNamesComputerModel', () {
    test('matches the model snapshot on the model or the full name', () {
      expect(
        sourceNamesComputerModel(
          computerModel: ' shearwater  PERDIX ',
          manufacturer: 'Shearwater',
          model: 'Perdix',
        ),
        isTrue,
      );
      expect(
        sourceNamesComputerModel(
          computerModel: 'Perdix',
          manufacturer: 'Shearwater',
          model: 'Perdix',
        ),
        isTrue,
      );
    });

    test('matches the descriptor product when the vendor agrees', () {
      expect(
        sourceNamesComputerModel(
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          manufacturer: 'Shearwater',
          model: 'Perdix',
        ),
        isTrue,
      );
      expect(
        sourceNamesComputerModel(
          descriptorProduct: 'Perdix',
          manufacturer: '',
          model: 'Perdix',
        ),
        isTrue,
      );
    });

    test('rejects a descriptor product from another vendor', () {
      expect(
        sourceNamesComputerModel(
          descriptorVendor: 'Mares',
          descriptorProduct: 'Perdix',
          manufacturer: 'Shearwater',
          model: 'Perdix',
        ),
        isFalse,
      );
    });

    test('never matches a computer without a model', () {
      expect(
        sourceNamesComputerModel(
          computerModel: 'Shearwater',
          manufacturer: 'Shearwater',
          model: null,
        ),
        isFalse,
      );
    });
  });

  group('matchOrphanedSources with a serial', () {
    test('links on model and serial', () {
      final result = matchOrphanedSources(
        sources: [source('s1', serial: 'ABC123')],
        computers: [
          computer('c1', serial: 'ABC123'),
          computer('c2', serial: 'XYZ999'),
        ],
      );
      expect(result, {'s1': 'c1'});
    });

    test('matches a Shearwater serial across hex and decimal', () {
      // 0x8629AC48 is 2250878024 in decimal.
      final result = matchOrphanedSources(
        sources: [
          source('s1', computerModel: 'Shearwater Teric', serial: '2250878024'),
        ],
        computers: [computer('c1', model: 'Teric', serial: '8629AC48')],
      );
      expect(result, {'s1': 'c1'});
    });

    test('does not link a serial that names another unit', () {
      final result = matchOrphanedSources(
        sources: [source('s1', serial: 'ABC123')],
        computers: [computer('c1', serial: 'XYZ999')],
      );
      expect(result, isEmpty);
    });

    test('does not link the same serial on another model', () {
      final result = matchOrphanedSources(
        sources: [source('s1', serial: 'ABC123')],
        computers: [computer('c1', model: 'Teric', serial: 'ABC123')],
      );
      expect(result, isEmpty);
    });

    test('does not link to another diver\'s computer', () {
      // A unit that changed hands: its old dives stay the old diver's.
      final result = matchOrphanedSources(
        sources: [source('s1', serial: 'ABC123', diverId: 'diver-a')],
        computers: [computer('c1', serial: 'ABC123', diverId: 'diver-b')],
      );
      expect(result, isEmpty);
    });

    test('links to a computer that names no diver', () {
      final result = matchOrphanedSources(
        sources: [source('s1', serial: 'ABC123', diverId: 'diver-a')],
        computers: [computer('c1', serial: 'ABC123')],
      );
      expect(result, {'s1': 'c1'});
    });

    test('does not choose between two entries with the same serial', () {
      final result = matchOrphanedSources(
        sources: [source('s1', serial: 'ABC123')],
        computers: [
          computer('c1', serial: 'ABC123'),
          computer('c2', serial: 'abc123'),
        ],
      );
      expect(result, isEmpty);
    });
  });

  group('matchOrphanedSources without a serial (issue #4465)', () {
    test('links to the only computer of that model', () {
      final result = matchOrphanedSources(
        sources: [
          source(
            's1',
            computerModel: null,
            vendor: 'Shearwater',
            product: 'Perdix',
          ),
        ],
        computers: [
          computer('c1', serial: 'ABC123'),
          computer('c2', model: 'Teric', serial: 'XYZ999'),
        ],
      );
      expect(result, {'s1': 'c1'});
    });

    test('does not guess between two computers of that model', () {
      final result = matchOrphanedSources(
        sources: [source('s1')],
        computers: [
          computer('c1', serial: 'ABC123'),
          computer('c2', serial: 'XYZ999'),
        ],
      );
      expect(result, isEmpty);
    });

    test('counts a computer of another diver as a second unit', () {
      final result = matchOrphanedSources(
        sources: [source('s1', diverId: 'diver-a')],
        computers: [
          computer('c1', serial: 'ABC123', diverId: 'diver-a'),
          computer('c2', serial: 'XYZ999', diverId: 'diver-b'),
        ],
      );
      expect(result, isEmpty);
    });

    test('does not link to the only computer when it is another diver\'s', () {
      final result = matchOrphanedSources(
        sources: [source('s1', diverId: 'diver-a')],
        computers: [computer('c1', serial: 'ABC123', diverId: 'diver-b')],
      );
      expect(result, isEmpty);
    });

    test(
      'does not guess when an orphan of that model names another serial',
      () {
        // s2 shows a second unit of this model existed, so s1 might be its.
        final result = matchOrphanedSources(
          sources: [
            source('s1', diveId: 'dive-1'),
            source('s2', diveId: 'dive-2', serial: 'OTHER1'),
          ],
          computers: [computer('c1', serial: 'ABC123')],
        );
        expect(result, isEmpty);
      },
    );

    test('an orphan naming the same serial does not block the guess', () {
      final result = matchOrphanedSources(
        sources: [
          source('s1', diveId: 'dive-1'),
          source('s2', diveId: 'dive-2', serial: 'abc123'),
        ],
        computers: [computer('c1', serial: 'ABC123')],
      );
      expect(result, {'s1': 'c1', 's2': 'c1'});
    });

    test(
      'does not link to a computer that already has a source on the dive',
      () {
        final result = matchOrphanedSources(
          sources: [source('s1', diveId: 'dive-1')],
          computers: [computer('c1', serial: 'ABC123')],
          linkedSources: const {(diveId: 'dive-1', computerId: 'c1')},
        );
        expect(result, isEmpty);
      },
    );

    test('does not link two serial-less orphans on one dive to one unit', () {
      // A diver carrying two units of the model: only one can be c1's.
      final result = matchOrphanedSources(
        sources: [source('s1'), source('s2')],
        computers: [computer('c1', serial: 'ABC123')],
      );
      expect(result, isEmpty);
    });

    test('does not guess on a dive where a serial claims the unit', () {
      final result = matchOrphanedSources(
        sources: [
          source('s1'),
          source('s2', serial: 'ABC123'),
        ],
        computers: [computer('c1', serial: 'ABC123')],
      );
      expect(result, {'s2': 'c1'});
    });

    test('links a serial-less orphan to a computer without a serial', () {
      final result = matchOrphanedSources(
        sources: [source('s1')],
        computers: [computer('c1')],
      );
      expect(result, {'s1': 'c1'});
    });
  });
}
