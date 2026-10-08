import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

void main() {
  group('DownloadedDive.computerTissue', () {
    DownloadedDive makeDive({ComputerTissueSnapshot? computerTissue}) =>
        DownloadedDive(
          startTime: DateTime.utc(2026, 3, 15, 10, 32),
          durationSeconds: 1800,
          maxDepth: 18.5,
          profile: const [],
          computerTissue: computerTissue,
        );

    test('is null when the computer reported no tissue state', () {
      expect(makeDive().computerTissue, isNull);
    });

    test('carries the snapshot the parser attached', () {
      const snapshot = ComputerTissueSnapshot(
        algorithm: 'Suunto Fused2 RGBM',
        start: ComputerTissueState(n2Bar: [0.79, 0.79]),
        end: ComputerTissueState(n2Bar: [0.9, 1.1], cnsPercent: 13.2),
      );

      final dive = makeDive(computerTissue: snapshot);

      expect(dive.computerTissue, snapshot);
      expect(dive.computerTissue!.hasCompartmentData, isTrue);
    });
  });

  group('DownloadedTank.copyWith', () {
    const tank = DownloadedTank(
      index: 2,
      o2Percent: 32,
      hePercent: 10,
      startPressure: 200,
      endPressure: 60,
      volumeLiters: 11.1,
      role: 'backGas',
      roleSource: TankRoleSource.transmitterName,
      transmitterSerial: 'TX-1',
    );

    test('keeps every field it is not given', () {
      final copy = tank.copyWith(role: 'sidemountLeft');

      expect(copy.role, 'sidemountLeft');
      expect(copy.index, 2);
      expect(copy.o2Percent, 32);
      expect(copy.hePercent, 10);
      expect(copy.startPressure, 200);
      expect(copy.endPressure, 60);
      expect(copy.volumeLiters, 11.1);
      expect(copy.roleSource, TankRoleSource.transmitterName);
      expect(copy.transmitterSerial, 'TX-1');
    });

    test('replaces each field it is given', () {
      final copy = tank.copyWith(
        index: 5,
        o2Percent: 50,
        hePercent: 0,
        startPressure: 210,
        endPressure: 50,
        volumeLiters: 7,
        roleSource: TankRoleSource.values.last,
        transmitterSerial: 'TX-2',
      );

      expect(copy.index, 5);
      expect(copy.o2Percent, 50);
      expect(copy.hePercent, 0);
      expect(copy.startPressure, 210);
      expect(copy.endPressure, 50);
      expect(copy.volumeLiters, 7);
      expect(copy.roleSource, TankRoleSource.values.last);
      expect(copy.transmitterSerial, 'TX-2');
    });
  });
}
