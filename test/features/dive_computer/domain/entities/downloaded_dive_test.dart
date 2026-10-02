import 'package:flutter_test/flutter_test.dart';
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
}
