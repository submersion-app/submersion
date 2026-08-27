import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Volumetric SAC under each gas model (issue #828).
///
/// The scenario is the one reported in the issue: a 12 L cylinder, 150 bar
/// consumed, 44 minutes, 13.2 m average depth. The reporter computed
/// 17.6 L/min by hand and the app showed 16.5, and read the gap as the app
/// padding the dive time by three minutes. It was not: the app was applying a
/// real-gas correction the reporter's arithmetic did not.
void main() {
  Dive reportedDive({required Duration runtime}) => Dive(
    id: 'dive-828',
    dateTime: DateTime(2026, 8, 4, 10),
    runtime: runtime,
    avgDepth: 13.2,
    tanks: const [
      DiveTank(
        id: 'tank-1',
        volume: 12.0,
        startPressure: 200.0,
        endPressure: 50.0,
        gasMix: GasMix(o2: 21.0, he: 0.0),
        role: TankRole.backGas,
      ),
    ],
  );

  group('Dive.sacFor', () {
    test('ideal model reproduces the hand calculation from issue #828', () {
      final dive = reportedDive(runtime: const Duration(minutes: 44));
      // 12 L * 150 bar = 1800 L, / (13.2/10 + 1) / 44 min
      expect(dive.sacFor(GasModel.ideal), closeTo(17.63, 0.01));
    });

    test('real model applies compressibility and reads lower', () {
      final dive = reportedDive(runtime: const Duration(minutes: 44));
      expect(dive.sacFor(GasModel.real), closeTo(16.77, 0.01));
    });

    test('uses the runtime verbatim, adding no safety stop padding', () {
      // The heart of the reported complaint. If anything padded the dive by
      // three minutes, the 44 and 47 minute results would be equal.
      final logged = reportedDive(runtime: const Duration(minutes: 44));
      final padded = reportedDive(runtime: const Duration(minutes: 47));
      expect(
        logged.sacFor(GasModel.ideal),
        isNot(closeTo(padded.sacFor(GasModel.ideal)!, 0.01)),
      );
      expect(
        padded.sacFor(GasModel.ideal),
        closeTo(logged.sacFor(GasModel.ideal)! * 44 / 47, 0.01),
      );
    });

    test('returns null without tanks, runtime, or average depth', () {
      final noTanks = Dive(
        id: 'd1',
        dateTime: DateTime(2026, 8, 4),
        runtime: const Duration(minutes: 44),
        avgDepth: 13.2,
      );
      expect(noTanks.sacFor(GasModel.real), isNull);

      final noDepth = Dive(
        id: 'd2',
        dateTime: DateTime(2026, 8, 4),
        runtime: const Duration(minutes: 44),
        tanks: const [
          DiveTank(
            id: 't',
            volume: 12.0,
            startPressure: 200.0,
            endPressure: 50.0,
          ),
        ],
      );
      expect(noDepth.sacFor(GasModel.real), isNull);
    });
  });

  group('Dive.sacPressure', () {
    test('is model independent, being a pure pressure drop per minute', () {
      final dive = reportedDive(runtime: const Duration(minutes: 44));
      // 150 bar / 44 min / 2.32 bar ambient
      expect(dive.sacPressure, closeTo(1.469, 0.001));
    });
  });
}
