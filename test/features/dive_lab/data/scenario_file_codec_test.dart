import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/data/services/scenario_file_codec.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_snapshot.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

DiveSnapshot _snapshot() => DiveSnapshot(
  diveId: 'dive-1',
  diveDateTime: DateTime.utc(2026, 8, 1, 9, 30),
  siteName: 'Blue Hole',
  gfLow: 35,
  gfHigh: 75,
  waterType: WaterType.salt,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 200,
      endPressure: 80,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    ),
    DiveTank(
      id: 'deco50',
      volume: 11.1,
      startPressure: 200,
      endPressure: 150,
      gasMix: GasMix(o2: 50),
      role: TankRole.deco,
    ),
  ],
  gasSwitches: const [ScenarioGasSwitch(timestamp: 1600, tankId: 'deco50')],
  profile: const [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 10, depth: 3.5, temperature: 24.1),
    DiveProfilePoint(timestamp: 20, depth: 7.0),
  ],
  tankPressures: const {
    'back': [
      TankPressureSample(timestamp: 0, pressureBar: 200),
      TankPressureSample(timestamp: 20, pressureBar: 198.5),
    ],
  },
  computerName: 'Perdix',
);

DiveScenario _scenario() => DiveScenario(
  id: 'sc-1',
  diveId: 'dive-1',
  name: 'Lost 50%',
  notes: 'for the instructor',
  branchSeconds: 1420,
  mode: ScenarioMode.replan,
  interventions: const [
    LoseTankIntervention(tankId: 'deco50'),
    ChangeGfIntervention(gfLow: 40, gfHigh: 85),
  ],
  createdAt: DateTime.utc(2026, 8, 21, 10),
  updatedAt: DateTime.utc(2026, 8, 21, 11),
);

void main() {
  test('snapshot JSON round trip', () {
    final s = _snapshot();
    final back = DiveSnapshot.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
    );
    expect(back, s);
  });

  test('sublab round trip keeps the scenario and the snapshot', () {
    final json = scenarioToSublabJson(
      scenario: _scenario(),
      snapshot: _snapshot(),
      appVersion: '1.9.0',
    );
    final file = sublabFromJson(json);
    expect(file.scenario, _scenario());
    expect(file.snapshot, _snapshot());
    expect(file.appVersion, '1.9.0');
    final map = jsonDecode(json) as Map;
    expect(map['format'], sublabFormat);
    expect(map['version'], sublabVersion);
  });

  test('rejects foreign, newer and malformed files', () {
    expect(() => sublabFromJson('nope'), throwsFormatException);
    expect(
      () => sublabFromJson(jsonEncode({'format': 'other', 'version': 1})),
      throwsFormatException,
    );
    expect(
      () => sublabFromJson(
        jsonEncode({'format': sublabFormat, 'version': 99, 'scenario': {}}),
      ),
      throwsFormatException,
    );
    expect(
      () => sublabFromJson(jsonEncode({'format': sublabFormat, 'version': 1})),
      throwsFormatException,
    );
    final noProfile =
        jsonDecode(
              scenarioToSublabJson(
                scenario: _scenario(),
                snapshot: _snapshot(),
              ),
            )
            as Map<String, Object?>;
    (noProfile['diveSnapshot'] as Map)['profile'] = [];
    expect(() => sublabFromJson(jsonEncode(noProfile)), throwsFormatException);
  });
}
