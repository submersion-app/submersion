import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/trim_calculator/domain/trim_fixes.dart';

/// What would level the diver (spec section 14 B): fixes in the order
/// instructors try them, each with the verdict it leads to.
void main() {
  final body = TrimBody(heightCm: 175, bodyMassKg: 80);
  const pose = TrimPose.standard;

  TrimElement lead(
    String id,
    double kg,
    TrimSpot spot, {
    TrimLateral lateral = TrimLateral.centre,
  }) => TrimElement(
    id: id,
    label: id,
    kind: TrimElementKind.lead,
    sinkKg: kg,
    spot: spot,
    lateral: lateral,
  );

  const fins = TrimElement(
    id: 'fins',
    label: 'Fins',
    kind: TrimElementKind.gear,
    sinkKg: kVentedFinSinkKg,
    spot: TrimSpot.fins,
  );
  const tank = TrimElement(
    id: 'tank',
    label: 'AL80',
    kind: TrimElementKind.tank,
    sinkKg: -1.4,
    spot: TrimSpot.backTank,
    valveSinkKg: 0.7,
  );

  TrimScene scene(List<TrimElement> elements, {double net = -1}) => TrimScene(
    elements: elements,
    modelNetKg: net,
    liftSpot: TrimSpot.wing,
    body: body,
    timestamp: 0,
    suitLiftKg: 7,
  );

  List<TrimFix> fixes(TrimScene s, {double step = 0.5}) =>
      suggestTrimFixes(s, pose, leadStepKg: step);

  test('a level, steady diver needs nothing', () {
    final s = scene([
      tank,
      lead('hips', 4, TrimSpot.hipPockets),
      lead('trim', 2, TrimSpot.trimPockets),
    ]);
    expect(s.trimIn(pose).pitch, TrimVerdict.level);
    expect(fixes(s), isEmpty);
  });

  test('every fix improves on today, and there are at most three', () {
    final s = scene([tank, lead('belt', 8, TrimSpot.waist), fins], net: -3);
    final before = s.trimIn(pose).pitchKgM.abs();
    final found = fixes(s);
    expect(found, isNotEmpty);
    expect(found.length, lessThanOrEqualTo(3));
    for (final f in found) {
      expect(f.result.pitchKgM.abs(), lessThan(before));
    }
  });

  test('an overweighted diver is told to carry less lead first', () {
    final s = scene([tank, lead('belt', 8, TrimSpot.waist), fins], net: -3);
    final first = fixes(s).first;
    expect(first.kind, TrimFixKind.lessLead);
    expect(first.kg, 3);
  });

  test('a diver within 1.5 kg of neutral is not told to drop lead', () {
    final s = scene([tank, lead('belt', 8, TrimSpot.waist), fins]);
    expect(fixes(s).map((f) => f.kind), isNot(contains(TrimFixKind.lessLead)));
  });

  test('feet-heavy: lighter fins, and lead moved up to the trim pockets', () {
    final s = scene([tank, lead('belt', 8, TrimSpot.waist), fins]);
    expect(s.trimIn(pose).pitchKgM, greaterThan(kLevelBandKgM));
    final found = fixes(s);
    final finFix = found.where((f) => f.kind == TrimFixKind.lighterFins);
    expect(finFix.single.kg, kSplitFinSinkKg);
    final move = found.where((f) => f.kind == TrimFixKind.moveLead).single;
    expect(move.from, TrimSpot.waist);
    expect(move.to, TrimSpot.trimPockets);
    expect(move.kg! % 0.5, closeTo(0, 1e-9));
  });

  test('head-heavy: lead moved down to the hip pockets', () {
    final s = scene([
      const TrimElement(
        id: 'steel',
        label: 'Steel 15',
        kind: TrimElementKind.tank,
        sinkKg: 1.5,
        spot: TrimSpot.backTank,
        valveSinkKg: 0.7,
      ),
      lead('plate', 3, TrimSpot.backplate),
      lead('trim', 4, TrimSpot.trimPockets),
    ]);
    expect(s.trimIn(pose).pitchKgM, lessThan(-kLevelBandKgM));
    final move = fixes(s).where((f) => f.kind == TrimFixKind.moveLead).single;
    expect(move.to, TrimSpot.hipPockets);
    expect(move.result.pitchKgM.abs(), lessThan(s.trimIn(pose).pitchKgM.abs()));
  });

  test('a back tank is offered a slide on its band', () {
    final s = scene([tank, lead('belt', 8, TrimSpot.waist), fins]);
    final slide = fixes(
      s,
    ).where((f) => f.kind == TrimFixKind.tankHeight).firstOrNull;
    expect(slide, isNotNull);
    expect(slide!.metres!.abs(), inInclusiveRange(0.05, 0.10));
  });

  test('a roll is fixed by moving lead to the light side', () {
    final s = scene([
      tank,
      lead('left', 3, TrimSpot.hipPockets, lateral: TrimLateral.left),
      lead('trim', 2, TrimSpot.trimPockets),
    ]);
    expect(s.trimIn(pose).roll, isNot(RollVerdict.level));
    final roll = fixes(s).where((f) => f.kind == TrimFixKind.moveAcross).single;
    expect(roll.fromSide, TrimLateral.left);
    expect(roll.result.roll, RollVerdict.level);
    expect(roll.kg, 1.5);
  });

  test('in pounds, lead moves in whole pounds', () {
    const lb = 0.45359237;
    final s = scene([tank, lead('belt', 8, TrimSpot.waist), fins], net: -3);
    for (final f in fixes(s, step: lb)) {
      if (f.kind == TrimFixKind.lessLead || f.kind == TrimFixKind.moveLead) {
        final pounds = f.kg! / lb;
        expect(pounds, closeTo(pounds.roundToDouble(), 1e-9));
      }
    }
  });

  test('lead split between left and right pockets comes off both sides', () {
    final s = scene([
      tank,
      lead('left', 3, TrimSpot.hipPockets, lateral: TrimLateral.left),
      lead('right', 3, TrimSpot.hipPockets, lateral: TrimLateral.right),
      lead('trim', 1, TrimSpot.trimPockets),
      fins,
    ], net: -2.2);
    final found = fixes(s);
    final less = found.where((f) => f.kind == TrimFixKind.lessLead).single;
    expect(less.kg, 2);
    expect(less.result.roll, RollVerdict.level);
    final move = fixes(
      s,
    ).where((f) => f.kind == TrimFixKind.moveLead).firstOrNull;
    if (move != null) expect(move.result.roll, RollVerdict.level);
  });

  test('a tank already slid to the end is not slid further', () {
    final s = scene([
      tank.copyWith(shiftM: kTrimTankShiftMaxM),
      lead('belt', 8, TrimSpot.waist),
      fins,
    ]);
    for (final f in fixes(s).where((f) => f.kind == TrimFixKind.tankHeight)) {
      expect(
        (kTrimTankShiftMaxM + f.metres!).abs(),
        lessThanOrEqualTo(kTrimTankShiftMaxM + 1e-9),
      );
    }
  });

  test('when no amount levels a roll, the best amount is offered', () {
    // One-sided lead with a sided tank: no move of lead alone levels it.
    final s = scene([
      const TrimElement(
        id: 'pony',
        label: 'Pony',
        kind: TrimElementKind.tank,
        sinkKg: 3,
        spot: TrimSpot.sidemount,
        lateral: TrimLateral.right,
      ),
      lead('right', 1.5, TrimSpot.hipPockets, lateral: TrimLateral.right),
      lead('trim', 2, TrimSpot.trimPockets),
    ]);
    final roll = fixes(
      s,
    ).where((f) => f.kind == TrimFixKind.moveAcross).singleOrNull;
    if (roll == null) return;
    for (final kg in [0.5, 1.0, 1.5]) {
      final other = s
          .copyWith(
            elements: [
              for (final e in s.elements)
                e.id == 'right' ? e.copyWith(sinkKg: e.sinkKg - kg) : e,
              lead('moved', kg, TrimSpot.hipPockets, lateral: TrimLateral.left),
            ],
          )
          .trimIn(pose);
      expect(
        roll.result.rollKgM.abs(),
        lessThanOrEqualTo(other.rollKgM.abs() + 1e-9),
      );
    }
  });
}
