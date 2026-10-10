import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/computer_recorded_tank.dart';
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

void main() {
  const handAdded = DiveTank(id: 't1', gasMix: GasMix(o2: 32), order: 2);

  group('isComputerRecordedTank', () {
    test('a hand-added tank is not', () {
      expect(isComputerRecordedTank(handAdded), isFalse);
    });

    test('a tank a download attributed to a computer is', () {
      expect(
        isComputerRecordedTank(handAdded.copyWith(computerId: 'dc1')),
        isTrue,
      );
    });

    test('a tank carrying a parsed source index is', () {
      expect(
        isComputerRecordedTank(handAdded.copyWith(sourceTankIndex: 0)),
        isTrue,
      );
    });

    test('a row a reassignment left behind, with no computer, is not', () {
      expect(
        isComputerRecordedTank(
          handAdded.copyWith(sourceTankIndex: kNoSourceTankIndex),
        ),
        isFalse,
      );
    });
  });

  group('computerTankIndex', () {
    test('is the source index when the row has one', () {
      expect(
        computerTankIndex(
          handAdded.copyWith(computerId: 'dc1', sourceTankIndex: 1),
        ),
        1,
      );
    });

    test('falls back to the order on a pre-v200 computer row', () {
      expect(computerTankIndex(handAdded.copyWith(computerId: 'dc1')), 2);
    });

    test('is null for a hand-added tank', () {
      expect(computerTankIndex(handAdded), isNull);
    });

    test('is null for a row that takes no parsed tank', () {
      expect(
        computerTankIndex(
          handAdded.copyWith(
            computerId: 'dc1',
            sourceTankIndex: kNoSourceTankIndex,
          ),
        ),
        isNull,
      );
    });
  });
}
