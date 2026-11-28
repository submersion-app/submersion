import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';

/// The reference rigs the trim figure is tuned to (spec 7.5, decided
/// 2026-11-25): a 175 cm, 80 kg diver in salt water at the final stop, in
/// the standard pose, in a 7 mm wetsuit (7 kg of lift spread over the body),
/// with
/// a wing holding 1 kg of overweighting. Each rig must give its verdict.
void main() {
  final body = TrimBody(heightCm: 175, bodyMassKg: 80);

  double tankSinkKg(String preset, TankMaterial material, double volumeL) =>
      -twinTankKgAt(
        TwinTankInput(
          id: preset,
          label: preset,
          presetName: preset,
          volumeL: volumeL,
          material: material,
        ),
        50,
      );

  TrimElement el(String id, double kg, TrimSpot spot) => TrimElement(
    id: id,
    label: id,
    kind: TrimElementKind.lead,
    sinkKg: kg,
    spot: spot,
  );

  // A cylinder carries its valve at its top end (spec section 14 C).
  TrimElement tank(String id, double kg) => TrimElement(
    id: id,
    label: id,
    kind: TrimElementKind.tank,
    sinkKg: kg - kTankValveSinkKg,
    spot: TrimSpot.backTank,
    valveSinkKg: kTankValveSinkKg,
  );

  final al80 = tank('al80', tankSinkKg('al80', TankMaterial.aluminum, 11.1));
  final steel15 = tank(
    'steel15',
    tankSinkKg('steel15', TankMaterial.steel, 15),
  );

  TrimResult rig(List<TrimElement> elements, {TrimPose? pose}) => computeTrim(
    body: body,
    pose: pose ?? TrimPose.standard,
    elements: elements,
    modelNetKg: -1,
    liftSpot: TrimSpot.wing,
    // A 7 mm full wetsuit's lift at the stop, as the model's prior gives it.
    suitLiftKg: 7,
  );

  final rig1 = [
    al80,
    el('hips', 4, TrimSpot.hipPockets),
    el('trim', 2, TrimSpot.trimPockets),
    el('fins', kPaddleFinSinkKg, TrimSpot.fins),
  ];
  final rig2 = [
    al80,
    el('belt', 6, TrimSpot.waist),
    el('fins', kPaddleFinSinkKg, TrimSpot.fins),
  ];
  final rig3 = [
    al80,
    el('belt', 6, TrimSpot.waist),
    el('fins', kVentedFinSinkKg, TrimSpot.fins),
  ];
  final rig4 = [
    steel15,
    el('plate', 2, TrimSpot.backplate),
    el('trim', 2, TrimSpot.trimPockets),
    el('fins', kSplitFinSinkKg, TrimSpot.fins),
  ];

  test('rig 1 (4 kg hips, 2 kg trim, paddle fins) reads level', () {
    expect(rig(rig1).pitch, TrimVerdict.level);
  });

  test('rig 2 (6 kg belt, paddle fins) reads slightly feet-heavy', () {
    expect(rig(rig2).pitch, TrimVerdict.slightlyFeetHeavy);
  });

  test('rig 3 (6 kg belt, vented fins) reads feet-heavy', () {
    expect(rig(rig3).pitch, TrimVerdict.feetHeavy);
  });

  test('rig 4 (steel 15 L, backplate and trim lead, split fins) reads '
      'slightly head-heavy', () {
    expect(rig(rig4).pitch, TrimVerdict.slightlyHeadHeavy);
  });

  test('each rig sits inside its band, not on an edge', () {
    double margin(double v, double lo, double hi) =>
        [v - lo, hi - v].reduce((a, b) => a < b ? a : b);
    expect(
      margin(rig(rig1).pitchKgM, -kLevelBandKgM, kLevelBandKgM),
      greaterThan(0.05),
    );
    expect(
      margin(rig(rig2).pitchKgM, kLevelBandKgM, kSlightBandKgM),
      greaterThan(0.05),
    );
    expect(rig(rig3).pitchKgM - kSlightBandKgM, greaterThan(0.05));
    expect(
      margin(-rig(rig4).pitchKgM, kLevelBandKgM, kSlightBandKgM),
      greaterThan(0.05),
    );
  });

  test('knee bend 90 is less feet-heavy than 0 for rig 3', () {
    expect(
      rig(rig3).pitchKgM,
      lessThan(
        rig(rig3, pose: TrimPose(armReach: 0.5, kneeBendDeg: 0)).pitchKgM,
      ),
    );
  });

  test('reaching ahead with a light is more head-heavy than arms back', () {
    final light = [...rig1, el('light', 1.2, TrimSpot.hand)];
    expect(
      rig(light, pose: TrimPose(armReach: 1, kneeBendDeg: 90)).pitchKgM,
      lessThan(
        rig(light, pose: TrimPose(armReach: 0, kneeBendDeg: 90)).pitchKgM,
      ),
    );
  });

  test('the float point stays between the nipple line and the navel', () {
    final s = body.floatPoint.s / body.heightM;
    expect(s, inInclusiveRange(0.28, 0.40));
  });

  test('fin defaults stay inside measured pairs', () {
    // Splits near neutral up to a Hollis F1 pair (1.18 kg), with slack.
    for (final kg in [kPaddleFinSinkKg, kSplitFinSinkKg, kVentedFinSinkKg]) {
      expect(kg, inInclusiveRange(0.0, 1.3));
    }
  });
}
