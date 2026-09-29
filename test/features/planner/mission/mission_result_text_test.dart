import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final base = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );
  final mission = MissionEdits.updateLeg(
    MissionEdits.updateMember(
      base,
      base.team.single.copyWith(
        scooter: const ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    ),
    base.legs.single.copyWith(label: 'T'),
  );

  test(
    'the constraint sentence names the diver, scooter, place and factor',
    () {
      const limited = MissionOutcome(
        segments: [],
        cruiseSpeedMps: 0.9,
        legs: [],
        // Real outcomes record each waypoint's leg id; the sentence names
        // the leg through it.
        waypoints: [
          WaypointOutcome(
            index: 0,
            legId: 'L1',
            cumulativeDistanceM: 0,
            arrivalRuntimeSeconds: 0,
            directDistanceHomeM: 0,
            safeSurfaceSeconds: null,
            members: [],
            survivable: true,
          ),
        ],
        members: [],
        abandonmentIndex: null,
        constraint: MissionConstraint(
          memberId: 'm1',
          factor: MissionBindingFactor.battery,
          waypointIndex: 0,
        ),
        issues: [],
      );
      expect(
        missionConstraintText(l10n, limited, mission),
        "Limited by Sam's Blacktip at T: battery reserve",
      );
    },
  );

  test(
    'a constraint naming a diver no longer on the team reads as computing',
    () {
      const stale = MissionOutcome(
        segments: [],
        cruiseSpeedMps: 0.9,
        legs: [],
        waypoints: [],
        members: [],
        abandonmentIndex: null,
        constraint: MissionConstraint(
          memberId: 'gone',
          factor: MissionBindingFactor.battery,
          waypointIndex: 0,
        ),
        issues: [],
      );
      expect(
        missionConstraintText(l10n, stale, mission),
        'Working out the failure scenarios',
      );
    },
  );

  test('every binding factor has a label', () {
    for (final factor in MissionBindingFactor.values) {
      expect(missionFactorLabel(l10n, factor), isNotEmpty, reason: factor.name);
    }
  });

  test('numbers round up, never to nearest', () {
    expect(ceilMinutes(61), 2);
    expect(ceilMinutes(60), 1);
    expect(ceilPercent(0.334), '34');
    const metric = UnitFormatter(AppSettings());
    expect(ceilPressure(metric, 170.2), '171 bar');
    expect(ceilDistance(metric, 212.1), '213m');
    const imperial = UnitFormatter(
      AppSettings(depthUnit: DepthUnit.feet, pressureUnit: PressureUnit.psi),
    );
    // 170.2 bar is 2468.6 psi: up to 2469.
    expect(ceilPressure(imperial, 170.2), '2469 psi');
  });

  test('a battery percent is not pushed up by binary noise', () {
    // 0.55 * 100 is 55.00000000000001 in binary floating point.
    expect(ceilPercent(0.55), '55');
    expect(ceilPercent(0.551), '56');
  });

  test('the reserve reads as the diver set it', () {
    expect(settingPercent(1 / 3), '33');
    expect(settingPercent(0.55), '55');
  });

  test('a diver whose scooter has no name is named alone', () {
    final unnamed = MissionEdits.updateMember(
      mission,
      mission.team.single.copyWith(
        scooter: mission.team.single.scooter.copyWith(name: '  '),
      ),
    );
    const limited = MissionOutcome(
      segments: [],
      cruiseSpeedMps: 0.9,
      legs: [],
      waypoints: [
        WaypointOutcome(
          index: 0,
          legId: 'L1',
          cumulativeDistanceM: 0,
          arrivalRuntimeSeconds: 0,
          directDistanceHomeM: 0,
          safeSurfaceSeconds: null,
          members: [],
          survivable: true,
        ),
      ],
      members: [],
      abandonmentIndex: null,
      constraint: MissionConstraint(
        memberId: 'm1',
        factor: MissionBindingFactor.ownGas,
        waypointIndex: 0,
      ),
      issues: [],
    );
    expect(
      missionConstraintText(l10n, limited, unnamed),
      'Limited by Sam at T: own gas',
    );
  });

  test('binary noise does not add a unit to a rounded-up figure', () {
    const metric = UnitFormatter(AppSettings());
    expect(ceilPressure(metric, 150.00000000000003), '150 bar');
    expect(ceilDistance(metric, 300.00000000000006), '300m');
  });
}
