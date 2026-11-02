import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

void main() {
  final at = DateTime.utc(2026, 5, 1, 9);

  test('a plan keeps its settings under unit-named keys', () {
    final doc = divePlanDocument(
      DivePlan(
        id: 'p',
        name: 'Deep',
        createdAt: at,
        updatedAt: at,
        startDateTime: at,
        descentRate: 18,
        lastStopDepth: 6,
        sacBottom: 16,
        reservePressure: 50,
        ppO2Bottom: 1.3,
        maxO2DepthMeters: 6,
        surfaceInterval: const Duration(hours: 2),
        stopMinimums: const {6: 180},
        plannedWeightKg: 8,
      ),
    );
    expect(doc['start_date_time'], '2026-05-01T09:00:00.000Z');
    expect(doc['descent_rate_m_min'], 18.0);
    expect(doc['last_stop_depth_m'], 6.0);
    expect(doc['sac_bottom_l_min'], 16.0);
    expect(doc['reserve_pressure_bar'], 50.0);
    expect(doc['ppo2_bottom_bar'], 1.3);
    expect(doc['max_o2_depth_m'], 6.0);
    expect(doc['surface_interval_s'], 7200);
    expect(doc['stop_minimums_s'], {'6': 180});
    expect(doc['planned_weight_kg'], 8.0);
    expect(doc['mission'], isNull);
  });

  test('segments carry depth, duration and gas fractions', () {
    final doc = divePlanDocument(
      DivePlan(
        id: 'p',
        name: 'Deep',
        createdAt: at,
        updatedAt: at,
        tanks: const [
          DiveTank(id: 't', gasMix: GasMix(o2: 32), role: TankRole.backGas),
        ],
        segments: const [
          PlanSegment(
            id: 's',
            targetDepth: 30,
            durationSeconds: 1200,
            tankId: 't',
            gasMix: GasMix(o2: 32, he: 10),
          ),
        ],
      ),
    );
    final segment = (doc['segments'] as List).cast<Map>().single;
    expect(segment['target_depth_m'], 30.0);
    expect(segment['duration_s'], 1200);
    expect(segment['tank_id'], 't');
    expect(segment['o2_fraction'], closeTo(0.32, 1e-9));
    expect(segment['he_fraction'], closeTo(0.10, 1e-9));
    expect((doc['tanks'] as List).cast<Map>().single['id'], 't');
  });

  test('a mission lists its legs and team', () {
    final doc = divePlanDocument(
      DivePlan(
        id: 'p',
        name: 'Scooter',
        createdAt: at,
        updatedAt: at,
        mission: const DpvMission(
          batteryReserveFraction: 0.33,
          walkSpeedMps: 1.2,
          legs: [
            MissionLeg(
              id: 'l',
              order: 0,
              label: 'Out',
              distanceM: 800,
              depthM: 25,
              headingDeg: 90,
            ),
          ],
          team: [
            MissionMember(
              id: 'm',
              order: 0,
              displayName: 'Ann',
              sacBottom: 15,
              scooter: ScooterSpec(
                name: 'Seacraft',
                ratedSpeedMps: 1.5,
                burnTimeSeconds: 7200,
              ),
            ),
          ],
        ),
      ),
    );
    final mission = doc['mission'] as Map;
    expect(mission['environment'], 'overhead');
    expect(mission['battery_reserve_fraction'], 0.33);
    expect(mission['walk_speed_m_s'], 1.2);
    final leg = (mission['legs'] as List).cast<Map>().single;
    expect(leg['distance_m'], 800.0);
    expect(leg['heading_deg'], 90.0);
    final member = (mission['team'] as List).cast<Map>().single;
    expect(member['display_name'], 'Ann');
    expect(member['sac_bottom_l_min'], 15.0);
  });
}
