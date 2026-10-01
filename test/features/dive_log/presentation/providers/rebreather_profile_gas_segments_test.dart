import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// Issue #2593: the gas schedule a rebreather dive's tissues load from. Null
/// means the loop cannot be modelled and the analysis withholds tissue loading
/// rather than fall back to open circuit on the first cylinder.
void main() {
  const o2 = DiveTank(
    id: 'o2',
    gasMix: GasMix(o2: 100),
    role: TankRole.oxygenSupply,
  );
  const diluent = DiveTank(
    id: 'dil',
    gasMix: GasMix(o2: 10, he: 50),
    role: TankRole.diluent,
  );
  const supply = DiveTank(id: 'supply', gasMix: GasMix(o2: 32));

  List<DiveProfilePoint> profile({
    double? setpoint,
    double? ppO2,
    double? cell,
  }) => [
    for (final (t, d) in [(0, 0.0), (120, 82.0), (1200, 82.0), (2400, 0.0)])
      DiveProfilePoint(
        timestamp: t,
        depth: d,
        setpoint: setpoint,
        ppO2: ppO2,
        o2Sensor1: cell,
      ),
  ];

  List<ProfileGasSegmentView>? segmentsFor(Dive dive) {
    final segments = buildRebreatherProfileGasSegments(
      dive,
      profile: dive.profile,
      rebreatherPpO2: resolveRebreatherPpO2(dive.profile),
    );
    return segments
        ?.map((s) => (fN2: s.fN2, fHe: s.fHe, setpoint: s.setpoint))
        .toList();
  }

  group('CCR', () {
    test('loads on the diluent at the recorded setpoint', () {
      final dive = Dive(
        id: 'ccr',
        dateTime: DateTime.utc(2026, 9, 18),
        diveMode: DiveMode.ccr,
        tanks: const [o2, diluent],
        profile: profile(setpoint: 1.3),
      );

      expect(segmentsFor(dive), [(fN2: 0.4, fHe: 0.5, setpoint: 1.3)]);
    });

    test('falls back to the dive-level setpoint', () {
      final dive = Dive(
        id: 'ccr',
        dateTime: DateTime.utc(2026, 9, 18),
        diveMode: DiveMode.ccr,
        tanks: const [o2, diluent],
        setpointHigh: 1.2,
        profile: profile(),
      );

      expect(segmentsFor(dive), [(fN2: 0.4, fHe: 0.5, setpoint: 1.2)]);
    });

    test('is null with no setpoint and no measured ppO2', () {
      final dive = Dive(
        id: 'ccr',
        dateTime: DateTime.utc(2026, 9, 18),
        diveMode: DiveMode.ccr,
        tanks: const [o2, diluent],
        profile: profile(),
      );

      expect(segmentsFor(dive), isNull);
    });
  });

  group('SCR', () {
    test('loads on the supply gas at the measured loop ppO2', () {
      final dive = Dive(
        id: 'scr',
        dateTime: DateTime.utc(2026, 9, 18),
        diveMode: DiveMode.scr,
        tanks: const [supply],
        profile: profile(cell: 0.9),
      );

      expect(segmentsFor(dive), [(fN2: 0.68, fHe: 0.0, setpoint: 0.9)]);
    });

    test('takes the computer-supplied loop ppO2 as measured', () {
      final dive = Dive(
        id: 'scr',
        dateTime: DateTime.utc(2026, 9, 18),
        diveMode: DiveMode.scr,
        tanks: const [supply],
        profile: profile(ppO2: 1.1),
      );

      expect(segmentsFor(dive), [(fN2: 0.68, fHe: 0.0, setpoint: 1.1)]);
    });

    test(
      'is null on a setpoint alone: a semi-closed loop does not hold one',
      () {
        final dive = Dive(
          id: 'scr',
          dateTime: DateTime.utc(2026, 9, 18),
          diveMode: DiveMode.scr,
          tanks: const [supply],
          setpointHigh: 1.3,
          profile: profile(setpoint: 1.3),
        );

        expect(segmentsFor(dive), isNull);
      },
    );
  });

  test('is null for open circuit and gauge dives', () {
    for (final mode in [DiveMode.oc, DiveMode.gauge]) {
      final dive = Dive(
        id: mode.name,
        dateTime: DateTime.utc(2026, 9, 18),
        diveMode: mode,
        tanks: const [supply],
        profile: profile(cell: 1.0),
      );

      expect(segmentsFor(dive), isNull, reason: mode.name);
    }
  });
}

typedef ProfileGasSegmentView = ({double fN2, double fHe, double? setpoint});
