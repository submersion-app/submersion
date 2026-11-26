import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';

/// The posable body the trim figure balances (issue #5028).
void main() {
  final body = TrimBody(heightCm: 175, bodyMassKg: 80);

  test('no height or mass falls back to 175 cm and the default mass', () {
    final fallback = TrimBody();
    expect(fallback.heightM, 1.75);
    expect(fallback.massKg, BuoyancyPhysics.defaultBodyMassKg);
  });

  test('a pose clamps arm reach to 0..1 and knee bend to 0..90', () {
    final pose = TrimPose(armReach: 2, kneeBendDeg: 120);
    expect(pose.armReach, 1);
    expect(pose.kneeBendDeg, 90);
    expect(TrimPose(armReach: -1, kneeBendDeg: -5).kneeBendDeg, 0);
  });

  test('knee bend 0 puts the ankle behind the knee on the body line', () {
    final pose = TrimPose(armReach: 0.5, kneeBendDeg: 0);
    final ankle = body.ankle(pose);
    expect(ankle.s, greaterThan(body.knee.s));
    expect(ankle.z, closeTo(body.knee.z, 1e-9));
  });

  test('knee bend 90 lifts the ankle above the knee', () {
    final pose = TrimPose(armReach: 0.5, kneeBendDeg: 90);
    final ankle = body.ankle(pose);
    expect(ankle.s, closeTo(body.knee.s, 1e-9));
    expect(ankle.z, greaterThan(body.knee.z));
  });

  test('the foot always points to the rear', () {
    for (final bend in [0.0, 30.0, 60.0, 90.0]) {
      final pose = TrimPose(armReach: 0.5, kneeBendDeg: bend);
      expect(body.segmentAngle(TrimSegment.foot, pose), 0, reason: '$bend');
      expect(body.segmentAngle(TrimSegment.farFoot, pose), 0);
    }
  });

  test('the shin turns by the knee bend', () {
    final pose = TrimPose(armReach: 0.5, kneeBendDeg: 90);
    expect(
      body.segmentAngle(TrimSegment.shin, pose),
      closeTo(math.pi / 2, 1e-9),
    );
  });

  test('arm reach 1 puts the hand ahead of the crown', () {
    expect(body.hand(TrimPose(armReach: 1, kneeBendDeg: 0)).s, lessThan(0));
  });

  test('arm reach 0 puts the hand between the hip and the knee', () {
    final hand = body.hand(TrimPose(armReach: 0, kneeBendDeg: 0));
    expect(hand.s, greaterThan(body.hip.s));
    expect(hand.s, lessThan(body.knee.s));
  });

  test('arm reach 0.5 hangs the hand below the shoulder', () {
    final hand = body.hand(TrimPose.standard);
    expect(hand.s, closeTo(body.shoulder.s, 1e-9));
    expect(hand.z, lessThan(body.shoulder.z));
  });

  test('limbs sink slightly', () {
    final masses = body.limbMasses(TrimPose.standard);
    expect(masses, isNotEmpty);
    for (final m in masses) {
      expect(m.inWaterKg, inExclusiveRange(0, 1), reason: '${m.segment}');
    }
  });

  test('both arms and both legs are counted', () {
    final segments = body.limbMasses(TrimPose.standard).map((m) => m.segment);
    expect(
      segments.toSet(),
      containsAll([
        TrimSegment.arm,
        TrimSegment.farArm,
        TrimSegment.shin,
        TrimSegment.farShin,
        TrimSegment.foot,
        TrimSegment.farFoot,
        TrimSegment.torso,
      ]),
    );
  });

  test('the float point sits on the torso between shoulder and hip', () {
    expect(body.floatPoint.s, greaterThan(body.shoulder.s));
    expect(body.floatPoint.s, lessThan(body.hip.s));
    expect(body.floatPoint.z, 0);
  });

  test('a taller diver has longer levers', () {
    final tall = TrimBody(heightCm: 195, bodyMassKg: 80);
    expect(tall.knee.s, greaterThan(body.knee.s));
  });

  group('measured body (research D, E)', () {
    test('the float point sits at the measured 0.385 of height', () {
      expect(body.floatPoint.s / body.heightM, closeTo(0.385, 0.002));
    });

    test('in the measured pose the bare body has the measured torque', () {
      const streamline = (armReach: 1.0, kneeBendDeg: 0.0);
      for (final (sex, mass, d) in [
        (DiverSex.male, 80.0, 0.0193),
        (DiverSex.female, 60.0, 0.0136),
        (null, 70.0, 0.0165),
      ]) {
        final b = TrimBody(heightCm: 175, bodyMassKg: mass, sex: sex);
        final pitch = computeTrim(
          body: b,
          pose: TrimPose(
            armReach: streamline.armReach,
            kneeBendDeg: streamline.kneeBendDeg,
          ),
          elements: const [],
          modelNetKg: 0,
          liftSpot: TrimSpot.floatPoint,
          waterDensity: 1.0,
        ).pitchKgM;
        expect(pitch, closeTo(mass * d, 1e-6), reason: '$sex');
      }
    });

    test('a suit\'s lift is split by coverage and thickness', () {
      double torso(List<double> panels) =>
          body.suitShares(TrimPose.standard, panelsMm: panels).first.$2;
      final shares = body.suitShares(TrimPose.standard, panelsMm: const [7, 5]);
      expect(shares.fold(0.0, (s, e) => s + e.$2), closeTo(1, 1e-9));
      expect(torso(const [7, 5]), greaterThan(torso(const [5])));
      expect(torso(const [5]), closeTo(0.42 / 0.995, 0.01));
    });
  });
}
