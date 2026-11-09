import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/gas_mod_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_time_suggestions.dart';

import '../../helpers/quality_test_helpers.dart';

/// A suit inflation bottle is not breathing gas (issue #4243): the gas
/// checks never read it as the gas in use.
void main() {
  domain.DiveTank tank(
    String id, {
    double o2 = 21,
    int order = 0,
    TankRole role = TankRole.backGas,
  }) => domain.DiveTank(
    id: id,
    volume: 12,
    gasMix: domain.GasMix(o2: o2),
    order: order,
    role: role,
  );

  test('a hypoxic suit bottle listed first raises no hypoxic finding', () {
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank('suit', o2: 10, role: TankRole.suitInflation),
          tank('back', order: 1),
        ],
      ),
      samples: flatProfile(depth: 2),
    );

    expect(const GasModDetector().detect(ctx), isEmpty);
  });

  test('a suit bottle listed first is not the gas in use', () {
    // Back gas drains before the switch to deco: it was the gas in use, so
    // nothing is attributed to an idle tank.
    final ctx = makeContext(
      dive: makeTestDive(
        tanks: [
          tank('suit', role: TankRole.suitInflation),
          tank('back', order: 1),
          tank('deco', o2: 50, order: 2, role: TankRole.deco),
        ],
      ),
      pressures: {
        'back': const [
          QualityPressureSample(t: 0, bar: 200),
          QualityPressureSample(t: 600, bar: 170),
          QualityPressureSample(t: 1200, bar: 140),
        ],
        'suit': const [
          QualityPressureSample(t: 0, bar: 200),
          QualityPressureSample(t: 1800, bar: 150),
        ],
      },
      gasSwitches: [
        GasSwitch(
          id: 'gs1',
          diveId: 'd1',
          timestamp: 1200,
          tankId: 'deco',
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      ],
    );

    expect(const TankAssignmentDetector().detect(ctx), isEmpty);
  });

  test('a suit bottle offers no gas switch times', () {
    expect(
      hasBreathingStarts(
        const domain.DiveTank(id: 's', role: TankRole.suitInflation),
      ),
      isFalse,
    );
    expect(hasBreathingStarts(const domain.DiveTank(id: 'b')), isTrue);
  });
}
