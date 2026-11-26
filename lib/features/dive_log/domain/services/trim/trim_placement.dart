import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_position.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Where one element sits on the trim figure, and the side-view artwork
/// drawn for it (issue #5028).
class TrimPlacement {
  const TrimPlacement(
    this.spot, {
    this.lateral = TrimLateral.centre,
    this.pieceIds = const [],
  });

  final TrimSpot spot;
  final TrimLateral lateral;

  /// Keys of `trimArtwork`; empty when the element is drawn as a chip.
  final List<String> pieceIds;
}

/// The trim spot for a gear figure zone. Gear is placed by the gear
/// figure's composer, so its rules (figure position, worn as, sidemount
/// rigs, zone capacity) are the trim figure's too. A null zone (the tray)
/// and the suit zones act at the float point: the tray holds what has no
/// spot on the body, and a suit's lift is spread along it.
TrimPlacement trimPlacementForZone(FigureZone? zone) => switch (zone) {
  null ||
  FigureZone.suit ||
  FigureZone.underlayer => const TrimPlacement(TrimSpot.floatPoint),
  FigureZone.head ||
  FigureZone.face ||
  FigureZone.hud ||
  FigureZone.maskStrap => const TrimPlacement(TrimSpot.head),
  FigureZone.mouth || FigureZone.octo => const TrimPlacement(TrimSpot.mouth),
  FigureZone.chest ||
  FigureZone.torsoFront => const TrimPlacement(TrimSpot.chest),
  FigureZone.chestClipLeft => const TrimPlacement(
    TrimSpot.chestClip,
    lateral: TrimLateral.left,
  ),
  FigureZone.chestClipRight => const TrimPlacement(
    TrimSpot.chestClip,
    lateral: TrimLateral.right,
  ),
  FigureZone.stageLeft => const TrimPlacement(
    TrimSpot.stageClip,
    lateral: TrimLateral.left,
  ),
  FigureZone.stageRight => const TrimPlacement(
    TrimSpot.stageClip,
    lateral: TrimLateral.right,
  ),
  FigureZone.wristLeft => const TrimPlacement(
    TrimSpot.wrist,
    lateral: TrimLateral.left,
  ),
  FigureZone.wristRight => const TrimPlacement(
    TrimSpot.wrist,
    lateral: TrimLateral.right,
  ),
  FigureZone.hands || FigureZone.dpv => const TrimPlacement(TrimSpot.hand),
  FigureZone.handLeft => const TrimPlacement(
    TrimSpot.hand,
    lateral: TrimLateral.left,
  ),
  FigureZone.handRight => const TrimPlacement(
    TrimSpot.hand,
    lateral: TrimLateral.right,
  ),
  FigureZone.cameraArm => const TrimPlacement(
    TrimSpot.cameraArm,
    lateral: TrimLateral.right,
  ),
  FigureZone.console => const TrimPlacement(
    TrimSpot.console,
    lateral: TrimLateral.left,
  ),
  FigureZone.waist => const TrimPlacement(TrimSpot.waist),
  FigureZone.hipLeft => const TrimPlacement(
    TrimSpot.hipPockets,
    lateral: TrimLateral.left,
  ),
  FigureZone.hipRight => const TrimPlacement(
    TrimSpot.hipPockets,
    lateral: TrimLateral.right,
  ),
  FigureZone.thighLeft => const TrimPlacement(
    TrimSpot.thigh,
    lateral: TrimLateral.left,
  ),
  FigureZone.thighRight => const TrimPlacement(
    TrimSpot.thigh,
    lateral: TrimLateral.right,
  ),
  FigureZone.calfLeft => const TrimPlacement(
    TrimSpot.calf,
    lateral: TrimLateral.left,
  ),
  FigureZone.ankles => const TrimPlacement(TrimSpot.ankles),
  FigureZone.feet => const TrimPlacement(TrimSpot.feet),
  FigureZone.fins => const TrimPlacement(TrimSpot.fins),
  FigureZone.tankValve => const TrimPlacement(TrimSpot.upperBack),
  FigureZone.backTank => const TrimPlacement(TrimSpot.backTank),
  FigureZone.wing => const TrimPlacement(TrimSpot.wing),
  FigureZone.backplate => const TrimPlacement(TrimSpot.backplate),
  FigureZone.trimLeft => const TrimPlacement(
    TrimSpot.trimPockets,
    lateral: TrimLateral.left,
  ),
  FigureZone.trimRight => const TrimPlacement(
    TrimSpot.trimPockets,
    lateral: TrimLateral.right,
  ),
  FigureZone.buttDRing => const TrimPlacement(TrimSpot.buttDRing),
  FigureZone.sidemountLeft => const TrimPlacement(
    TrimSpot.sidemount,
    lateral: TrimLateral.left,
  ),
  FigureZone.sidemountRight => const TrimPlacement(
    TrimSpot.sidemount,
    lateral: TrimLateral.right,
  ),
};

TrimLateral _lateralOf(WeightSide? side) => switch (side) {
  WeightSide.left => TrimLateral.left,
  WeightSide.right => TrimLateral.right,
  null => TrimLateral.centre,
};

/// A typed weight entry's spot; backplate weight is always centred.
TrimPlacement trimPlacementForWeight(WeightType? type, WeightSide? side) {
  final lateral = _lateralOf(side);
  return switch (type) {
    WeightType.integrated => TrimPlacement(
      TrimSpot.hipPockets,
      lateral: lateral,
      pieceIds: const ['weights_hip_side'],
    ),
    WeightType.trimWeights => TrimPlacement(
      TrimSpot.trimPockets,
      lateral: lateral,
      pieceIds: const ['weights_trim_side'],
    ),
    WeightType.backplate => const TrimPlacement(
      TrimSpot.backplate,
      pieceIds: ['weights_backplate_side'],
    ),
    WeightType.ankleWeights => TrimPlacement(
      TrimSpot.ankles,
      lateral: lateral,
      pieceIds: const ['weights_ankle_side'],
    ),
    // A belt, a mixed entry or no type at all: the waist, the usual place
    // when the spot is not known.
    WeightType.belt || WeightType.mixed || null => TrimPlacement(
      TrimSpot.waist,
      lateral: lateral,
      pieceIds: const ['weights_belt_side'],
    ),
  };
}

/// Lead carried as weights gear: its figure position when the diver chose
/// one, else its `weight_style`, else the backplate, where unstyled weights
/// gear (weighted plates, V-weights, tank adapters) is carried.
TrimPlacement trimPlacementForWeightsGear(Map<String, String?> attributes) {
  final zone = figurePositionZone(attributes[EquipmentAttrKeys.figurePosition]);
  if (zone != null) return trimPlacementForZone(zone);
  return switch (attributes[EquipmentAttrKeys.weightStyle]) {
    'belt' => trimPlacementForWeight(WeightType.belt, null),
    'integrated' => trimPlacementForWeight(WeightType.integrated, null),
    'trim' => trimPlacementForWeight(WeightType.trimWeights, null),
    'ankle' => trimPlacementForWeight(WeightType.ankleWeights, null),
    _ => trimPlacementForWeight(WeightType.backplate, null),
  };
}

/// A dive tank's spot from its role, unless its cylinder says how it is
/// worn (`worn_as`).
TrimPlacement trimPlacementForTank(TankRole role, {String? wornAs}) {
  final worn = wornAsZones(wornAs);
  if (worn.isNotEmpty) {
    final zone = worn.first;
    final at = trimPlacementForZone(zone);
    return TrimPlacement(
      at.spot,
      lateral: at.lateral,
      pieceIds: _tankPieces(at.spot),
    );
  }
  final TrimPlacement at = switch (role) {
    TankRole.sidemountLeft => const TrimPlacement(
      TrimSpot.sidemount,
      lateral: TrimLateral.left,
    ),
    TankRole.sidemountRight => const TrimPlacement(
      TrimSpot.sidemount,
      lateral: TrimLateral.right,
    ),
    // Stages hang on the left, the usual convention.
    TankRole.stage || TankRole.deco || TankRole.bailout => const TrimPlacement(
      TrimSpot.stageClip,
      lateral: TrimLateral.left,
    ),
    TankRole.backGas ||
    TankRole.twinSet ||
    TankRole.hydrotank ||
    TankRole.pony ||
    TankRole.diluent ||
    TankRole.oxygenSupply ||
    TankRole.suitInflation => const TrimPlacement(TrimSpot.backTank),
  };
  return TrimPlacement(
    at.spot,
    lateral: at.lateral,
    pieceIds: role == TankRole.twinSet
        ? const ['tank_doubles_side']
        : _tankPieces(at.spot),
  );
}

List<String> _tankPieces(TrimSpot spot) => switch (spot) {
  TrimSpot.sidemount => const ['tank_sidemount_side'],
  TrimSpot.stageClip => const ['tank_stage_side'],
  _ => const ['tank_single_side'],
};

/// A pair of fins' in-water weight (positive sinks) when the diver entered
/// none. The buoyancy model leaves fins at 0 (they fold into the personal
/// term), which would hide the "heavy fins" case trim is for. Tuned with the
/// reference rigs (spec 7.5); vented is the jet-fin style.
double trimFinSinkKg(Map<String, String?> attributes) =>
    switch (attributes['blade_style']) {
      'vented' => kVentedFinSinkKg,
      'split' => kSplitFinSinkKg,
      _ => kPaddleFinSinkKg,
    };

const double kPaddleFinSinkKg = 0.6;
const double kSplitFinSinkKg = 0.2;
const double kVentedFinSinkKg = 1.4;

/// Camera parts the gear figure leaves in the tray; on the trim figure they
/// weigh where the camera is (a float arm trims the camera rig).
bool isCameraAccessory(EquipmentType type) => const {
  EquipmentType.lens,
  EquipmentType.port,
  EquipmentType.trayHandle,
  EquipmentType.armClamp,
  EquipmentType.floatArm,
  EquipmentType.strobe,
  EquipmentType.videoLight,
}.contains(type);
