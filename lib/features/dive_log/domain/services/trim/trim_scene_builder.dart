import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_figure_inputs.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_piece_ids.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Everything the trim figure weighs for one moment of one dive (issue
/// #5028).
class TrimScene {
  const TrimScene({
    required this.elements,
    required this.modelNetKg,
    required this.liftSpot,
    required this.body,
    required this.timestamp,
    this.suitLiftKg = 0,
    this.shortySuit = false,
  });

  final List<TrimElement> elements;

  /// The exposure suit's lift at [timestamp], spread over the body.
  final double suitLiftKg;

  /// A shorty covers no forearms or shins.
  final bool shortySuit;

  /// The buoyancy model's net at [timestamp]: negative is heavy.
  final double modelNetKg;

  /// Where the lift that holds a heavy diver neutral acts.
  final TrimSpot liftSpot;
  final TrimBody body;

  /// The moment shown, seconds into the dive; -1 for the no-profile
  /// convention.
  final int timestamp;

  TrimScene copyWith({List<TrimElement>? elements}) => TrimScene(
    elements: elements ?? this.elements,
    modelNetKg: modelNetKg,
    liftSpot: liftSpot,
    body: body,
    timestamp: timestamp,
    suitLiftKg: suitLiftKg,
    shortySuit: shortySuit,
  );

  /// Pitch and roll of this scene in [pose].
  TrimResult trimIn(TrimPose pose) => computeTrim(
    body: body,
    pose: pose,
    elements: elements,
    modelNetKg: modelNetKg,
    liftSpot: liftSpot,
    suitLiftKg: suitLiftKg,
    shortySuit: shortySuit,
  );
}

/// Turns a logged [dive] and its buoyancy [outcome] into trim elements at
/// [timestamp] (null: the model's rest anchor, its final stop).
///
/// Gear is placed by the gear figure's composer, so trim and the gear figure
/// agree on where each item is; each item weighs its physical prior (see
/// [TwinStaticTerm.priorKg]), its parts and children included.
TrimScene buildTrimScene({
  required Dive dive,
  required BuoyancyTwinOutcome outcome,
  required int? timestamp,
  double? heightCm,
  double? bodyMassKg,
}) {
  final result = outcome.result;
  final verdict = outcome.outputs.verdict;
  final at = timestamp ?? verdict.anchor.timestamp;

  return TrimScene(
    elements: [
      ..._lead(dive),
      ..._gear(dive, result.input.staticTerms),
      ..._tanks(dive, result.input, at),
    ],
    modelNetKg: timestamp == null
        ? verdict.netKg
        : _netAt(result.samples, at, verdict.netKg),
    liftSpot: _liftSpot(dive.equipment),
    body: TrimBody(heightCm: heightCm, bodyMassKg: bodyMassKg),
    timestamp: at,
    suitLiftKg: timestamp == null
        ? _suitAtAnchor(result.input, verdict)
        : _nearest(result.samples, at)?.suitKg ?? 0,
    shortySuit: _isShorty(dive.equipment),
  );
}

/// The suit's share of the verdict, which leads the terms when there is a
/// suit (as the balance bar reads it).
double _suitAtAnchor(TwinInput input, TwinVerdict verdict) {
  if (input.suit.kind == TwinSuitKind.none) return 0;
  final first = verdict.terms.firstOrNull;
  return first != null && first.label == 'suit'
      ? first.kg
      : input.suit.anchorKg;
}

List<TrimElement> _lead(Dive dive) => [
  for (final w in dive.weights)
    _leadElement(
      id: 'weight:${w.id}',
      label: w.label,
      kg: w.amountKg,
      type: w.weightType,
      at: trimPlacementForWeight(w.weightType, w.side),
    ),
  if (dive.weights.isEmpty && (dive.weightAmount ?? 0) > 0)
    _leadElement(
      id: 'weight:legacy',
      label: '',
      kg: dive.weightAmount!,
      type: dive.weightType,
      at: trimPlacementForWeight(dive.weightType, null),
    ),
  for (final item in dive.leadGear)
    _leadElement(
      id: 'gear-lead:${item.id}',
      label: item.name,
      kg: EquipmentLead.kgFor(item),
      at: trimPlacementForWeightsGear(figureAttributesOf(item)),
      itemId: item.id,
    ),
];

TrimElement _leadElement({
  required String id,
  required String label,
  required double kg,
  required TrimPlacement at,
  WeightType? type,
  String? itemId,
}) => TrimElement(
  id: id,
  label: label,
  kind: TrimElementKind.lead,
  sinkKg: kg,
  spot: at.spot,
  lateral: at.lateral,
  itemId: itemId,
  weightType: type,
  pieceIds: at.pieceIds,
);

List<TrimElement> _gear(Dive dive, List<TwinStaticTerm> terms) {
  final priorById = <String, double>{
    for (final t in terms)
      if (t.itemId != null) t.itemId!: t.priorKg ?? t.kg,
  };
  final nodes = [
    for (final node in GearTree.build(dive.gear))
      // Lead and cylinders are weighed from the weights and the tanks.
      if (node.link.item.type != EquipmentType.weights &&
          node.link.item.type != EquipmentType.tank)
        node,
  ];
  final model = composeFigure(
    figureInputsForDive([
      for (final n in nodes) n.link.item,
    ], tankRolesByItem(dive.tanks)),
    sidemountRig: sidemountRigFromTanks(dive.tanks),
  );
  TrimPlacement? camera;
  for (final placed in model.placed) {
    final type = placed.item.type;
    if (type == EquipmentType.camera || type == EquipmentType.housing) {
      camera ??= trimPlacementForZone(placed.zone);
    }
  }
  return [
    for (final node in nodes)
      _gearElement(
        node,
        priorById,
        model.byId(node.link.item.id)?.zone,
        camera,
        trimPieceIdsForGearPieces(
          model.byId(node.link.item.id)?.pieceIds ?? const [],
          shorty: _isShorty(dive.equipment),
        ),
      ),
  ];
}

bool _isShorty(List<EquipmentItem> items) => items.any(
  (i) =>
      i.type == EquipmentType.wetsuit &&
      i.attributes.any(
        (a) => a.key == EquipmentAttrKeys.suitStyle && a.valueText == 'shorty',
      ),
);

TrimElement _gearElement(
  GearNode node,
  Map<String, double> priorById,
  FigureZone? zone,
  TrimPlacement? camera,
  List<String> pieceIds,
) {
  final item = node.link.item;
  var at = trimPlacementForZone(zone);
  if (zone == null && camera != null && isCameraAccessory(item.type)) {
    at = camera;
  }
  double buoyancy = 0;
  void sum(GearNode n) {
    buoyancy += priorById[n.link.item.id] ?? 0;
    n.children.forEach(sum);
  }

  sum(node);
  final sinkKg = item.type == EquipmentType.fins && item.buoyancyKg == null
      ? trimFinSinkKg(figureAttributesOf(item))
      : -buoyancy;
  return TrimElement(
    id: 'gear:${item.id}',
    label: item.name,
    kind: TrimElementKind.gear,
    sinkKg: sinkKg,
    spot: at.spot,
    lateral: at.lateral,
    itemId: item.id,
    pieceIds: pieceIds,
  );
}

List<TrimElement> _tanks(Dive dive, TwinInput input, int at) {
  final byId = {for (final t in input.tanks) t.id: t};
  final itemsById = {for (final i in dive.equipment) i.id: i};
  return [
    for (final tank in dive.tanks)
      if (byId[tank.id] case final twin?)
        _tankElement(
          id: tank.id,
          label: tank.name ?? tank.presetName ?? '',
          role: tank.role,
          cylinder: itemsById[tank.equipmentId],
          twin: twin,
          pressureBar: at < 0
              ? BuoyancyPhysics.defaultReserveBar
              : twinTankPressureAt(
                  twin,
                  at,
                  input.profile.isEmpty ? 0 : input.profile.first.timestamp,
                  input.profile.isEmpty ? 0 : input.profile.last.timestamp,
                ),
        ),
  ];
}

TrimElement _tankElement({
  required String id,
  required String label,
  required TankRole role,
  required EquipmentItem? cylinder,
  required TwinTankInput twin,
  required double pressureBar,
}) {
  final place = trimPlacementForTank(
    role,
    wornAs: cylinder?.attributes
        .where((a) => a.key == EquipmentAttrKeys.wornAs)
        .firstOrNull
        ?.valueText,
  );
  return TrimElement(
    id: 'tank:$id',
    label: label,
    kind: TrimElementKind.tank,
    sinkKg: -twinTankKgAt(twin, pressureBar),
    spot: place.spot,
    lateral: place.lateral,
    itemId: cylinder?.id,
    pieceIds: place.pieceIds,
  );
}

double _netAt(List<TwinSample> samples, int at, double fallback) =>
    _nearest(samples, at)?.netKg ?? fallback;

TwinSample? _nearest(List<TwinSample> samples, int at) {
  TwinSample? best;
  for (final s in samples) {
    if (best == null ||
        (s.timestamp - at).abs() < (best.timestamp - at).abs()) {
      best = s;
    }
  }
  return best;
}

/// A wing (or a backplate's wing) lifts at mid-back; a jacket BCD's bladder
/// wraps the torso, and drysuit gas with no BCD fills the suit, so both
/// act at the float point.
TrimSpot _liftSpot(List<EquipmentItem> items) {
  for (final item in items) {
    if (item.type == EquipmentType.wing) return TrimSpot.wing;
    if (item.type == EquipmentType.bcd) {
      final style = item.attributes
          .where((a) => a.key == EquipmentAttrKeys.bcdStyle)
          .firstOrNull
          ?.valueText;
      return style == 'jacket' || style == null
          ? TrimSpot.floatPoint
          : TrimSpot.wing;
    }
  }
  return TrimSpot.floatPoint;
}
