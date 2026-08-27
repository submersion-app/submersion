import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Helper to create a dive with common SAC-test defaults.
Dive _sacDive({
  String id = 'test',
  Duration? bottomTime,
  Duration? runtime,
  DateTime? entryTime,
  DateTime? exitTime,
  double? avgDepth = 20.0,
  List<DiveTank> tanks = const [],
  List<DiveProfilePoint> profile = const [],
}) {
  return Dive(
    id: id,
    dateTime: DateTime(2024, 1, 1),
    bottomTime: bottomTime,
    runtime: runtime,
    entryTime: entryTime,
    exitTime: exitTime,
    avgDepth: avgDepth,
    tanks: tanks,
    profile: profile,
  );
}

const _singleTank = DiveTank(
  id: 't1',
  name: 'AL80',
  volume: 11.1,
  startPressure: 200,
  endPressure: 30,
);

void main() {
  sacReferenceTankTests();
  // ─────────────────────────────────────────────────────────────────────────
  // Dive.sac (L/min at surface)
  // ─────────────────────────────────────────────────────────────────────────
  group('Dive.sac', () {
    test('calculates correctly using runtime (issue #72 reproduction)', () {
      // Reproduce issue #72 exactly:
      // 170 bar used, AL80 (11.1L), avg depth 20.3m, runtime 42 min
      final dive = _sacDive(
        id: 'issue-72',
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: const [_singleTank],
      );
      // With Z-factor correction against the 1 bar reference (issue #828):
      // gasVol(200) - gasVol(30) ≈ 1808L, SAC = 1808 / 42 / 3.03 ≈ 14.21
      expect(dive.sacFor(GasModel.real)!, closeTo(14.21, 0.1));
    });

    test('uses effectiveRuntime via entry/exit when runtime is null', () {
      final dive = _sacDive(
        bottomTime: const Duration(minutes: 20),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 42),
        avgDepth: 20.3,
        tanks: const [_singleTank],
      );
      // Uses 42 min from entry/exit, not 20 min from bottomTime
      expect(dive.sacFor(GasModel.real)!, closeTo(14.21, 0.1));
    });

    test('falls back to bottomTime when no runtime source', () {
      final dive = _sacDive(
        bottomTime: const Duration(minutes: 30),
        avgDepth: 20.0,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Tank',
            volume: 12.0,
            startPressure: 200,
            endPressure: 50,
          ),
        ],
      );
      // (200-50) * 12 / 30 / (20/10+1) = 1800 / 30 / 3 = 20.0 (ideal)
      // With Z-factor: ≈ 18.77
      expect(dive.sacFor(GasModel.real)!, closeTo(19.02, 0.1));
    });

    // --- Null return cases ---

    test('returns null when no time source available', () {
      final dive = _sacDive(tanks: const [_singleTank]);
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('returns null when tanks are empty', () {
      final dive = _sacDive(runtime: const Duration(minutes: 42));
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('returns null when avgDepth is null', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        avgDepth: null,
        tanks: const [_singleTank],
      );
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('returns null when effectiveRuntime is zero', () {
      final dive = _sacDive(
        bottomTime: Duration.zero,
        tanks: const [_singleTank],
      );
      expect(dive.sacFor(GasModel.real), isNull);
    });

    // --- Tank edge cases ---

    test('skips tanks missing volume', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'No volume',
            startPressure: 200,
            endPressure: 30,
          ),
        ],
      );
      // No tanks with complete data → null
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('skips tanks missing start pressure', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        tanks: const [
          DiveTank(id: 't1', name: 'Tank', volume: 12.0, endPressure: 50),
        ],
      );
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('skips tanks missing end pressure', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        tanks: const [
          DiveTank(id: 't1', name: 'Tank', volume: 12.0, startPressure: 200),
        ],
      );
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('skips tanks with zero or negative pressure used', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Not used',
            volume: 12.0,
            startPressure: 200,
            endPressure: 200, // No gas consumed
          ),
        ],
      );
      expect(dive.sacFor(GasModel.real), isNull);
    });

    test('sums gas across multiple tanks', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 60),
        avgDepth: 10.0, // ambientPressure = 2.0 atm
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Back gas',
            volume: 12.0,
            startPressure: 200,
            endPressure: 100,
          ),
          DiveTank(
            id: 't2',
            name: 'Stage',
            volume: 7.0,
            startPressure: 200,
            endPressure: 150,
          ),
        ],
      );
      // Tank 1: gasVol(200)-gasVol(100) at 12L
      // Tank 2: gasVol(200)-gasVol(150) at 7L
      // With Z-factor correction: ≈ 11.70 L/min
      expect(dive.sacFor(GasModel.real)!, closeTo(11.86, 0.1));
    });

    test('skips invalid tanks but uses valid ones', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 60),
        avgDepth: 10.0,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Valid',
            volume: 12.0,
            startPressure: 200,
            endPressure: 100,
          ),
          DiveTank(
            id: 't2',
            name: 'No volume',
            startPressure: 200,
            endPressure: 150,
          ),
        ],
      );
      // Only Tank 1: gasVol(200)-gasVol(100) at 12L / 60 / 2.0 ≈ 9.14
      expect(dive.sacFor(GasModel.real)!, closeTo(9.26, 0.1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Dive.sacPressure (bar/min at surface)
  // ─────────────────────────────────────────────────────────────────────────
  group('Dive.sacPressure', () {
    test('calculates correctly using runtime (issue #72)', () {
      final dive = _sacDive(
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: const [_singleTank],
      );
      // (200-30) / 42 / (20.3/10+1) = 170 / 42 / 3.03 = 1.336
      expect(dive.sacPressure!, closeTo(1.34, 0.1));
    });

    test('uses effectiveRuntime via entry/exit when runtime is null', () {
      final dive = _sacDive(
        bottomTime: const Duration(minutes: 20),
        entryTime: DateTime(2024, 1, 1, 10, 0),
        exitTime: DateTime(2024, 1, 1, 10, 42),
        avgDepth: 20.3,
        tanks: const [_singleTank],
      );
      expect(dive.sacPressure!, closeTo(1.34, 0.1));
    });

    // --- Null return cases ---

    test('returns null when no time source available', () {
      final dive = _sacDive(tanks: const [_singleTank]);
      expect(dive.sacPressure, isNull);
    });

    test('returns null when tanks are empty', () {
      final dive = _sacDive(runtime: const Duration(minutes: 42));
      expect(dive.sacPressure, isNull);
    });

    test('returns null when avgDepth is null', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        avgDepth: null,
        tanks: const [_singleTank],
      );
      expect(dive.sacPressure, isNull);
    });

    test('returns null when effectiveRuntime is zero', () {
      final dive = _sacDive(
        bottomTime: Duration.zero,
        tanks: const [_singleTank],
      );
      expect(dive.sacPressure, isNull);
    });

    // --- Tank edge cases ---

    test('skips tanks with missing pressures', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        tanks: const [
          DiveTank(id: 't1', name: 'No start', endPressure: 50),
          DiveTank(id: 't2', name: 'No end', startPressure: 200),
        ],
      );
      expect(dive.sacPressure, isNull);
    });

    test('skips tanks with zero pressure used', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 42),
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Full',
            startPressure: 200,
            endPressure: 200,
          ),
        ],
      );
      expect(dive.sacPressure, isNull);
    });

    test('sacPressure on multi-tank dive uses back gas tank only', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 60),
        avgDepth: 10.0, // ambientPressure = 2.0 atm
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Back gas',
            startPressure: 200,
            endPressure: 100,
            role: TankRole.backGas,
          ),
          DiveTank(
            id: 't2',
            name: 'Stage',
            startPressure: 200,
            endPressure: 150,
            role: TankRole.stage,
          ),
        ],
      );
      // Back gas only: 100 bar used / 60 min / 2.0 atm = 0.833 bar/min
      expect(dive.sacPressure!, closeTo(0.833, 0.01));
    });

    test('sacPressure falls back to first tank when no back gas role', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 60),
        avgDepth: 10.0, // ambientPressure = 2.0 atm
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Stage 1',
            startPressure: 200,
            endPressure: 100,
            role: TankRole.stage,
          ),
          DiveTank(
            id: 't2',
            name: 'Stage 2',
            startPressure: 200,
            endPressure: 150,
            role: TankRole.stage,
          ),
        ],
      );
      // No back gas role — falls back to tanks.first: 100 bar / 60 min / 2.0 atm = 0.833
      expect(dive.sacPressure!, closeTo(0.833, 0.01));
    });

    test('does not require tank volume (unlike sac)', () {
      final dive = _sacDive(
        runtime: const Duration(minutes: 60),
        avgDepth: 10.0,
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'No volume',
            startPressure: 200,
            endPressure: 100,
          ),
        ],
      );
      // sacPressure works without volume
      // 100 / 60 / 2.0 = 0.833
      expect(dive.sacPressure!, closeTo(0.833, 0.01));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Issue reproduction tests
  // ─────────────────────────────────────────────────────────────────────────
  group('Issue regression tests', () {
    test('issue #72: SAC no longer inflated by bottom time', () {
      // Before fix: used bottomTime (20 min) → SAC ≈ 31.5 L/min
      // After fix: uses runtime (42 min) with Z-factor → SAC ≈ 14.02 L/min
      final dive = _sacDive(
        bottomTime: const Duration(minutes: 20),
        runtime: const Duration(minutes: 42),
        avgDepth: 20.3,
        tanks: const [_singleTank],
      );
      // Must NOT be ~31.5 (the old buggy value)
      expect(dive.sacFor(GasModel.real)!, lessThan(20.0));
      expect(dive.sacFor(GasModel.real)!, closeTo(14.21, 0.1));
    });

    test('issue #87: sacPressure uses runtime correctly', () {
      // Issue #87: 95 bar consumed in 70 min at avg depth ~15m
      // Reporter expected ~1.3 bar/min (at shallower depth), app showed 1.8
      // With our depth (15m, ambient 2.5 atm): 95 / 70 / 2.5 = 0.543 bar/min
      final dive = _sacDive(
        bottomTime: const Duration(minutes: 50),
        runtime: const Duration(minutes: 70),
        avgDepth: 15.0, // ambientPressure = 2.5 atm
        tanks: const [
          DiveTank(
            id: 't1',
            name: 'Tank',
            startPressure: 200,
            endPressure: 105,
          ),
        ],
      );
      // Verifies runtime (70 min) is used, not bottomTime (50 min)
      // With bottomTime: 95 / 50 / 2.5 = 0.76 (the old buggy value)
      expect(dive.sacPressure!, closeTo(0.543, 0.05));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Dive.sacReferenceTank (the cylinder the pressure lane reads)
// ─────────────────────────────────────────────────────────────────────────
void sacReferenceTankTests() {
  group('Dive.sacReferenceTank', () {
    const backGas = DiveTank(id: 'bg', role: TankRole.backGas);
    const stage = DiveTank(id: 'st', role: TankRole.stage, volume: 11.1);

    test('is null with no cylinders', () {
      expect(_sacDive().sacReferenceTank, isNull);
    });

    test('is the only cylinder on a single-tank dive, whatever its role', () {
      expect(_sacDive(tanks: const [stage]).sacReferenceTank?.id, 'st');
    });

    test('is the back gas on a multi-tank dive even when listed later', () {
      expect(
        _sacDive(tanks: const [stage, backGas]).sacReferenceTank?.id,
        'bg',
      );
    });

    test('falls back to the first cylinder when none is back gas', () {
      const deco = DiveTank(id: 'dc', role: TankRole.deco);
      expect(_sacDive(tanks: const [stage, deco]).sacReferenceTank?.id, 'st');
    });
  });
}
