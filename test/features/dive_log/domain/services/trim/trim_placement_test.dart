import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Where lead, gear and tanks sit on the trim figure (issue #5028).
void main() {
  test('every figure zone has a trim spot', () {
    for (final zone in FigureZone.values) {
      expect(() => trimPlacementForZone(zone), returnsNormally);
    }
    expect(trimPlacementForZone(null).spot, TrimSpot.floatPoint);
  });

  test("a zone's side is the diver's own side", () {
    expect(
      trimPlacementForZone(FigureZone.hipRight).lateral,
      TrimLateral.right,
    );
    expect(trimPlacementForZone(FigureZone.trimLeft).lateral, TrimLateral.left);
    expect(
      trimPlacementForZone(FigureZone.backTank).lateral,
      TrimLateral.centre,
    );
  });

  test('every EquipmentType composes to a trim placement', () {
    for (final type in EquipmentType.values) {
      final model = composeFigure([
        FigureItemInput(id: 'x', type: type, name: type.name),
      ]);
      final placed = model.byId('x');
      expect(
        () => trimPlacementForZone(placed?.zone),
        returnsNormally,
        reason: '$type',
      );
    }
  });

  test('suits and layers act at the float point', () {
    expect(trimPlacementForZone(FigureZone.suit).spot, TrimSpot.floatPoint);
    expect(
      trimPlacementForZone(FigureZone.underlayer).spot,
      TrimSpot.floatPoint,
    );
  });

  group('weights', () {
    test('weight types map as the spec table', () {
      expect(
        trimPlacementForWeight(WeightType.belt, null).spot,
        TrimSpot.waist,
      );
      expect(
        trimPlacementForWeight(WeightType.integrated, null).spot,
        TrimSpot.hipPockets,
      );
      expect(
        trimPlacementForWeight(WeightType.trimWeights, null).spot,
        TrimSpot.trimPockets,
      );
      expect(
        trimPlacementForWeight(WeightType.backplate, WeightSide.left),
        isA<TrimPlacement>()
            .having((p) => p.spot, 'spot', TrimSpot.backplate)
            .having((p) => p.lateral, 'lateral', TrimLateral.centre),
      );
      expect(
        trimPlacementForWeight(WeightType.ankleWeights, null).spot,
        TrimSpot.ankles,
      );
      expect(
        trimPlacementForWeight(WeightType.mixed, null).spot,
        TrimSpot.waist,
      );
      expect(trimPlacementForWeight(null, null).spot, TrimSpot.waist);
    });

    test("a weight's side becomes its lateral; both stays centre", () {
      expect(
        trimPlacementForWeight(WeightType.integrated, WeightSide.left).lateral,
        TrimLateral.left,
      );
      expect(
        trimPlacementForWeight(WeightType.integrated, null).lateral,
        TrimLateral.centre,
      );
    });

    test('weights gear follows its style, then its figure position', () {
      expect(
        trimPlacementForWeightsGear(const {'weight_style': 'trim'}).spot,
        TrimSpot.trimPockets,
      );
      expect(
        trimPlacementForWeightsGear(const {'weight_style': 'ankle'}).spot,
        TrimSpot.ankles,
      );
      final positioned = trimPlacementForWeightsGear(const {
        'weight_style': 'belt',
        'figure_position': 'hip_right',
      });
      expect(positioned.spot, TrimSpot.hipPockets);
      expect(positioned.lateral, TrimLateral.right);
    });

    test('unstyled weights gear sits at the backplate', () {
      expect(trimPlacementForWeightsGear(const {}).spot, TrimSpot.backplate);
    });
  });

  group('tanks', () {
    test('tank roles map as the spec table', () {
      for (final role in [
        TankRole.backGas,
        TankRole.twinSet,
        TankRole.hydrotank,
        TankRole.diluent,
        TankRole.oxygenSupply,
        TankRole.suitInflation,
        TankRole.pony,
      ]) {
        expect(
          trimPlacementForTank(role).spot,
          TrimSpot.backTank,
          reason: '$role',
        );
      }
      expect(
        trimPlacementForTank(TankRole.sidemountLeft).lateral,
        TrimLateral.left,
      );
      expect(
        trimPlacementForTank(TankRole.sidemountRight),
        isA<TrimPlacement>()
            .having((p) => p.spot, 'spot', TrimSpot.sidemount)
            .having((p) => p.lateral, 'lateral', TrimLateral.right),
      );
      for (final role in [TankRole.stage, TankRole.deco, TankRole.bailout]) {
        final p = trimPlacementForTank(role);
        expect(p.spot, TrimSpot.stageClip, reason: '$role');
        expect(p.lateral, TrimLateral.left, reason: '$role');
      }
    });

    test('every tank role places somewhere', () {
      for (final role in TankRole.values) {
        expect(() => trimPlacementForTank(role), returnsNormally);
      }
    });

    test('a twin set worn as one draws the doubles', () {
      expect(
        trimPlacementForTank(TankRole.backGas, wornAs: 'twin_set').pieceIds,
        ['tank_doubles_side'],
      );
    });

    test('worn_as wins over the role', () {
      expect(
        trimPlacementForTank(
          TankRole.backGas,
          wornAs: 'sidemount_right',
        ).lateral,
        TrimLateral.right,
      );
      expect(
        trimPlacementForTank(TankRole.backGas, wornAs: 'stage').spot,
        TrimSpot.stageClip,
      );
    });
  });

  group('fins', () {
    test('fins use the blade-style default', () {
      expect(
        trimFinSinkKg(const {'blade_style': 'vented'}),
        greaterThan(trimFinSinkKg(const {'blade_style': 'paddle'})),
      );
      expect(
        trimFinSinkKg(const {'blade_style': 'paddle'}),
        greaterThan(trimFinSinkKg(const {'blade_style': 'split'})),
      );
      expect(trimFinSinkKg(const {}), greaterThan(0));
    });
  });

  test('camera accessories are recognised', () {
    for (final type in [
      EquipmentType.lens,
      EquipmentType.port,
      EquipmentType.floatArm,
      EquipmentType.trayHandle,
      EquipmentType.armClamp,
    ]) {
      expect(isCameraAccessory(type), isTrue, reason: '$type');
    }
    expect(isCameraAccessory(EquipmentType.fins), isFalse);
  });
}
