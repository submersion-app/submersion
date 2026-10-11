import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';

void main() {
  group('matchImportedComputer serial tier (#3106)', () {
    test('a hex file serial adopts the decimal BLE row', () {
      final match = matchImportedComputer(
        model: 'Perdix 2',
        serialNumber: 'A1B2C3D4',
        diverId: 'd1',
        candidates: const [
          ImportedComputerCandidate(
            id: 'ble',
            diverId: 'd1',
            manufacturer: 'Shearwater',
            model: 'Perdix 2',
            serialNumber: '2712847316',
          ),
        ],
      );
      expect(match?.id, 'ble');
    });

    test('the decimal equivalence does not apply outside Shearwater', () {
      final match = matchImportedComputer(
        model: 'D5',
        manufacturer: 'Suunto',
        serialNumber: '00BC614E',
        candidates: const [
          ImportedComputerCandidate(
            id: 'x',
            model: 'D5',
            serialNumber: '12345678',
          ),
        ],
      );
      expect(match, isNull);
    });
  });
}
