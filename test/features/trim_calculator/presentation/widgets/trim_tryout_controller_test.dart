import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_tryout_controller.dart';

/// The try-out sheet's state (issue #5028): moves, sides, test items, pose
/// and time, none of it saved.
void main() {
  TrimScene sceneAt(int? t) => TrimScene(
    elements: [
      const TrimElement(
        id: 'lead',
        label: 'Belt',
        kind: TrimElementKind.lead,
        sinkKg: 6,
        spot: TrimSpot.waist,
        pieceIds: ['weights_belt_side'],
      ),
      const TrimElement(
        id: 'suit',
        label: 'Suit',
        kind: TrimElementKind.gear,
        sinkKg: 0,
        spot: TrimSpot.floatPoint,
      ),
      TrimElement(
        id: 'tank',
        label: 'AL80',
        kind: TrimElementKind.tank,
        sinkKg: (t ?? 60) == 0 ? 1.0 : -1.0,
        spot: TrimSpot.backTank,
        valveSinkKg: 0.7,
      ),
    ],
    modelNetKg: -1,
    liftSpot: TrimSpot.wing,
    body: TrimBody(heightCm: 175, bodyMassKg: 80),
    timestamp: t ?? 60,
  );

  TrimTryoutController controller() =>
      TrimTryoutController(sceneAt: sceneAt, openingTimestamp: 60);

  TrimElement el(TrimTryoutController c, String id) =>
      c.scene.elements.singleWhere((e) => e.id == id);

  test('moving lead to the trim pockets changes pitch', () {
    final c = controller();
    final before = c.result.pitchKgM;
    c.move('lead', TrimSpot.trimPockets);
    expect(el(c, 'lead').spot, TrimSpot.trimPockets);
    expect(c.result.pitchKgM, lessThan(before));
  });

  test('a moved element drops its drawing and keeps its chip', () {
    final c = controller()..move('lead', TrimSpot.trimPockets);
    expect(el(c, 'lead').pieceIds, isEmpty);
  });

  test('suits cannot be moved; tanks only between tank spots', () {
    final c = controller();
    expect(c.canMove(el(c, 'suit')), isFalse);
    expect(c.spotsFor(el(c, 'tank')), [
      TrimSpot.backTank,
      TrimSpot.sidemount,
      TrimSpot.stageClip,
    ]);
    expect(c.spotsFor(el(c, 'lead')), isNot(contains(TrimSpot.floatPoint)));
  });

  test('tapping cycles both, left, right on a sided spot', () {
    final c = controller()..move('lead', TrimSpot.hipPockets);
    c.cycleSide('lead');
    expect(el(c, 'lead').lateral, TrimLateral.left);
    c.cycleSide('lead');
    expect(el(c, 'lead').lateral, TrimLateral.right);
    c.cycleSide('lead');
    expect(el(c, 'lead').lateral, TrimLateral.centre);
  });

  test('a centred spot ignores a side change', () {
    final c = controller()
      ..move('lead', TrimSpot.backplate)
      ..cycleSide('lead');
    expect(el(c, 'lead').lateral, TrimLateral.centre);
  });

  test('a test item is added at the waist and weighs in', () {
    final c = controller();
    final before = c.result.balancingLiftKg;
    c.addTestItem('Canister', 1.5);
    final item = c.scene.elements.last;
    expect(item.kind, TrimElementKind.test);
    expect(item.spot, TrimSpot.waist);
    expect(item.label, 'Canister');
    expect(c.result.balancingLiftKg, before + 1.5);
  });

  test('the time changes the tanks and keeps every move', () {
    final c = controller()..move('lead', TrimSpot.trimPockets);
    c.setTimestamp(0);
    expect(el(c, 'tank').sinkKg, 1.0);
    expect(el(c, 'lead').spot, TrimSpot.trimPockets);
  });

  test('pose changes pitch', () {
    final c = controller();
    final bent = c.result.pitchKgM;
    c.setPose(TrimPose(armReach: 0.5, kneeBendDeg: 0));
    expect(c.result.pitchKgM, isNot(bent));
  });

  test('reset restores the scene, the standard pose and the opening time', () {
    final c = controller()
      ..move('lead', TrimSpot.trimPockets)
      ..addTestItem('x', 1)
      ..setPose(TrimPose(armReach: 1, kneeBendDeg: 0))
      ..setTimestamp(0);
    c.reset();
    expect(el(c, 'lead').spot, TrimSpot.waist);
    expect(c.scene.elements.length, 3);
    expect(c.pose, TrimPose.standard);
    expect(c.timestamp, 60);
  });

  test('every change notifies', () {
    final c = controller();
    var n = 0;
    c.addListener(() => n++);
    c
      ..move('lead', TrimSpot.trimPockets)
      ..cycleSide('lead')
      ..addTestItem('x', 1)
      ..setPose(TrimPose.standard)
      ..setTimestamp(0)
      ..reset();
    expect(n, 6);
  });

  group('tank height (research C)', () {
    test('a moved tank keeps its valve', () {
      final c = controller()..move('tank', TrimSpot.sidemount);
      expect(el(c, 'tank').valveSinkKg, 0.7);
    });

    test('slides a back-mounted tank along the band, and only the tank', () {
      final c = controller();
      final before = c.result.pitchKgM;
      c.setTankShift(-0.05);
      expect(el(c, 'tank').shiftM, -0.05);
      expect(el(c, 'lead').shiftM, 0);
      expect(c.tankShiftM, -0.05);
      expect(c.result.pitchKgM, isNot(closeTo(before, 1e-9)));
    });

    test('stays within 10 cm either way', () {
      final c = controller()..setTankShift(0.5);
      expect(c.tankShiftM, kTrimTankShiftMaxM);
      c.setTankShift(-0.5);
      expect(c.tankShiftM, -kTrimTankShiftMaxM);
    });

    test('a tank moved off the back does not slide', () {
      final c = controller()
        ..move('tank', TrimSpot.sidemount)
        ..setTankShift(0.05);
      expect(el(c, 'tank').shiftM, 0);
      expect(c.hasBackTank, isFalse);
    });

    test('there is a back tank to slide as logged', () {
      expect(controller().hasBackTank, isTrue);
    });

    test('Reset puts the tank back', () {
      final c = controller()
        ..setTankShift(0.08)
        ..reset();
      expect(c.tankShiftM, 0);
      expect(el(c, 'tank').shiftM, 0);
    });
  });

  test('fixes are worked out once per scene and pose', () {
    final c = controller();
    final first = c.fixes(0.5);
    expect(identical(c.fixes(0.5), first), isTrue);
    c.move('lead', TrimSpot.trimPockets);
    expect(identical(c.fixes(0.5), first), isFalse);
  });
}
