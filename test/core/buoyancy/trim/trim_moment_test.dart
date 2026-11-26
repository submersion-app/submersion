import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';

/// Pitch and roll of the posed diver about the float point (issue #5028).
void main() {
  final body = TrimBody(heightCm: 175, bodyMassKg: 80);
  const pose = TrimPose.standard;

  TrimElement lead(
    String id,
    double kg,
    TrimSpot spot, {
    TrimLateral lateral = TrimLateral.centre,
    TrimElementKind kind = TrimElementKind.lead,
  }) => TrimElement(
    id: id,
    label: id,
    kind: kind,
    sinkKg: kg,
    spot: spot,
    lateral: lateral,
  );

  TrimResult trim(
    List<TrimElement> elements, {
    double modelNetKg = 0,
    TrimSpot liftSpot = TrimSpot.floatPoint,
  }) => computeTrim(
    body: body,
    pose: pose,
    elements: elements,
    modelNetKg: modelNetKg,
    liftSpot: liftSpot,
  );

  final limbsOnly = trim(const []);

  test('weight at the float point gives no moment', () {
    final r = trim([lead('a', 5, TrimSpot.floatPoint)]);
    expect(r.pitchKgM, closeTo(limbsOnly.pitchKgM, 1e-9));
    expect(r.rollKgM, closeTo(0, 1e-9));
  });

  test('lead moved from trim pockets to hip pockets increases pitch', () {
    final high = trim([lead('a', 2, TrimSpot.trimPockets)]);
    final low = trim([lead('a', 2, TrimSpot.hipPockets)]);
    expect(low.pitchKgM, greaterThan(high.pitchKgM));
  });

  test('something floating at the fins makes the diver less feet-heavy', () {
    final r = trim([lead('a', -1, TrimSpot.fins, kind: TrimElementKind.gear)]);
    expect(r.pitchKgM, lessThan(limbsOnly.pitchKgM));
  });

  test('left and right lead of equal weight cancel in roll', () {
    final r = trim([
      lead('a', 2, TrimSpot.hipPockets, lateral: TrimLateral.left),
      lead('b', 2, TrimSpot.hipPockets, lateral: TrimLateral.right),
    ]);
    expect(r.rollKgM, closeTo(0, 1e-9));
  });

  test('1 kg on the right hip rolls the diver right', () {
    final r = trim([
      lead('a', 1, TrimSpot.hipPockets, lateral: TrimLateral.right),
    ]);
    expect(r.rollKgM, greaterThan(0));
  });

  test('centred spots ignore a side', () {
    final r = trim([
      lead('a', 2, TrimSpot.backplate, lateral: TrimLateral.right),
    ]);
    expect(r.rollKgM, closeTo(0, 1e-9));
  });

  test("an overweighted diver's wing lift acts at the wing", () {
    final atWing = trim(const [], modelNetKg: -3, liftSpot: TrimSpot.wing);
    final atFloat = trim(
      const [],
      modelNetKg: -3,
      liftSpot: TrimSpot.floatPoint,
    );
    final arm = TrimSpot.wing.pointOn(body, pose).s - body.floatPoint.s;
    expect(atWing.balancingLiftKg, 3);
    expect(atWing.pitchKgM - atFloat.pitchKgM, closeTo(-3 * arm, 1e-9));
    // Wing gas centres at mid-back, ahead of the upper-abdomen float point,
    // so an overweighted diver's wing lifts the shoulders: feet-down.
    expect(arm, lessThan(0));
    expect(atWing.pitchKgM, greaterThan(atFloat.pitchKgM));
  });

  test('a light diver gets no balancing lift', () {
    expect(trim(const [], modelNetKg: 2).balancingLiftKg, 0);
  });

  test('a test item adds its own lift', () {
    final without = trim(const [], modelNetKg: -1, liftSpot: TrimSpot.wing);
    final withItem = trim(
      [lead('t', 2, TrimSpot.waist, kind: TrimElementKind.test)],
      modelNetKg: -1,
      liftSpot: TrimSpot.wing,
    );
    expect(withItem.balancingLiftKg, without.balancingLiftKg + 2);
  });

  test('tilt is capped at 20 degrees', () {
    final r = trim([lead('a', 30, TrimSpot.fins)]);
    expect(r.tiltDeg, 20);
    expect(r.pitch, TrimVerdict.feetHeavy);
  });

  test('verdicts follow the bands', () {
    expect(verdictForPitch(0), TrimVerdict.level);
    expect(verdictForPitch(kSlightBandKgM), TrimVerdict.feetHeavy);
    expect(
      verdictForPitch(-(kLevelBandKgM + kSlightBandKgM) / 2),
      TrimVerdict.slightlyHeadHeavy,
    );
    expect(
      verdictForRoll((kRollLevelBandKgM + kRollSlightBandKgM) / 2),
      RollVerdict.slightlyRight,
    );
    expect(verdictForRoll(-kRollSlightBandKgM * 2), RollVerdict.left);
  });

  test('every spot has a point on the posed body', () {
    for (final spot in TrimSpot.values) {
      final p = spot.pointOn(body, pose);
      expect(p.s.isFinite && p.z.isFinite, isTrue, reason: '$spot');
    }
  });

  test('limb spots move with the pose', () {
    final bent = TrimSpot.fins.pointOn(body, pose);
    final straight = TrimSpot.fins.pointOn(body, pose.copyWith(kneeBendDeg: 0));
    expect(straight.s, greaterThan(bent.s));
    expect(TrimSpot.fins.segment, TrimSegment.foot);
    expect(TrimSpot.hand.segment, TrimSegment.arm);
  });

  test("a wetsuit's leg neoprene lifts the legs", () {
    final dry = computeTrim(
      body: body,
      pose: pose,
      elements: const [],
      modelNetKg: 0,
      liftSpot: TrimSpot.floatPoint,
    );
    final suited = computeTrim(
      body: body,
      pose: pose,
      elements: const [],
      modelNetKg: 0,
      liftSpot: TrimSpot.floatPoint,
      suitLiftKg: 7,
    );
    expect(suited.pitchKgM, lessThan(dry.pitchKgM));
  });

  test('a shorty lifts the legs less than a full suit', () {
    TrimResult suit({required bool shorty}) => computeTrim(
      body: body,
      pose: pose,
      elements: const [],
      modelNetKg: 0,
      liftSpot: TrimSpot.floatPoint,
      suitLiftKg: 5,
      shortySuit: shorty,
    );
    expect(
      suit(shorty: true).pitchKgM,
      greaterThan(suit(shorty: false).pitchKgM),
    );
  });

  test('limbs weigh more in fresh water', () {
    TrimResult at(double density) => computeTrim(
      body: body,
      pose: pose,
      elements: const [],
      modelNetKg: 0,
      liftSpot: TrimSpot.floatPoint,
      waterDensity: density,
    );
    expect(at(1.000).pitchKgM, greaterThan(at(1.025).pitchKgM));
  });

  test('a belt weight carried on one side rolls the diver', () {
    final r = trim([lead('a', 3, TrimSpot.waist, lateral: TrimLateral.left)]);
    expect(r.rollKgM, lessThan(0));
  });

  test('2 lb more on one hip reads as a slight roll (research A)', () {
    final r = trim([
      lead('a', 0.907, TrimSpot.hipPockets, lateral: TrimLateral.right),
    ]);
    expect(r.roll, RollVerdict.slightlyRight);
  });

  test('roll has its own, tighter bands', () {
    expect(verdictForRoll(kRollLevelBandKgM / 2), RollVerdict.level);
    expect(verdictForRoll(kRollSlightBandKgM * 1.1), RollVerdict.right);
    expect(kRollSlightBandKgM, lessThan(kLevelBandKgM));
  });

  test("a tank's valve weighs at its top end (research C)", () {
    TrimResult tank({double valve = 0, double shift = 0}) => trim([
      TrimElement(
        id: 't',
        label: 't',
        kind: TrimElementKind.tank,
        sinkKg: -1,
        spot: TrimSpot.backTank,
        valveSinkKg: valve,
        shiftM: shift,
      ),
    ]);
    final valveAt =
        TrimSpot.backTank.pointOn(body, pose).s -
        kTankValveOffsetM -
        body.floatPoint.s;
    expect(
      tank(valve: 0.7).pitchKgM - tank().pitchKgM,
      closeTo(0.7 * valveAt, 1e-9),
    );
    // Moved 10 cm toward the feet, a floating cylinder lifts the feet more.
    expect(
      tank(shift: 0.1).pitchKgM - tank().pitchKgM,
      closeTo(-1 * 0.1, 1e-9),
    );
  });

  test("a tank's total weight counts its valve", () {
    const tank = TrimElement(
      id: 'tank',
      label: 'AL80',
      kind: TrimElementKind.tank,
      sinkKg: -1.5,
      spot: TrimSpot.backTank,
      valveSinkKg: 0.7,
    );
    expect(tank.totalSinkKg, closeTo(-0.8, 1e-9));
  });
}
