import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/data_quality/domain/detectors/tank_assignment_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_time_suggestions.dart';

import '../../helpers/quality_test_helpers.dart';

/// An Avelo Hydrotank's pressure falls when water is pushed out, not only
/// when the diver breathes from it (issue #4657), so a fall says nothing
/// about a gas switch: no one-tap switch times from it, and no "wrong tank"
/// finding when it falls while the diver is on a pony.
void main() {
  domain.DiveTank tank(String id, TankRole role, {int order = 0}) =>
      domain.DiveTank(
        id: id,
        volume: 10,
        gasMix: const domain.GasMix(o2: 21),
        order: order,
        role: role,
      );

  test('a Hydrotank offers no breathing starts', () {
    expect(
      hasBreathingStarts(
        const domain.DiveTank(id: 'h', role: TankRole.hydrotank),
      ),
      isFalse,
    );
  });

  List<Object> findingsFor(TankRole first) =>
      const TankAssignmentDetector().detect(
        makeContext(
          dive: makeTestDive(
            tanks: [tank('main', first), tank('pony', TankRole.pony, order: 1)],
          ),
          pressures: {
            // Steady on the pony after the switch at 1200 s, then a purge
            // drops the main cylinder 60 bar while the pony is in use.
            'main': const [
              QualityPressureSample(t: 0, bar: 200),
              QualityPressureSample(t: 1200, bar: 170),
              QualityPressureSample(t: 1800, bar: 110),
              QualityPressureSample(t: 2400, bar: 50),
            ],
            'pony': const [
              QualityPressureSample(t: 0, bar: 200),
              QualityPressureSample(t: 1200, bar: 200),
              QualityPressureSample(t: 2400, bar: 195),
            ],
          },
          gasSwitches: [
            GasSwitch(
              id: 'gs1',
              diveId: 'd1',
              timestamp: 1200,
              tankId: 'pony',
              createdAt: DateTime.utc(2026, 11, 17),
            ),
          ],
        ),
      );

  test('a back gas falling while the pony is in use is still flagged', () {
    expect(findingsFor(TankRole.backGas), isNotEmpty);
  });

  test('a Hydrotank purge while the pony is in use is no finding', () {
    expect(findingsFor(TankRole.hydrotank), isEmpty);
  });
}
