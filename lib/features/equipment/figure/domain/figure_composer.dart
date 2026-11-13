import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_position.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The attribute key an item's own colour lives under.
const String kFigureColorAttribute = EquipmentAttrKeys.color;

/// `#RRGGBB` to ARGB, or null for anything else.
int? parseFigureColor(String? hex) {
  final code = normalizeEquipmentColor(hex);
  if (code == null) return null;
  return 0xFF000000 | int.parse(code.substring(1), radix: 16);
}

/// Places [items] on the figure and numbers them (spec sections 4.2 to 4.4).
///
/// Numbers follow the order of [items]; placement walks the canonical type
/// order so the outcome does not depend on the diver's sort setting.
///
/// An item the diver moved on the figure takes that spot first, ahead of
/// every item the set rule places, so an earlier type cannot take it (issue
/// #4493). A tank's dive role or Worn as is tried first in its own turn,
/// and within the tanks those come before the ones with no place of their
/// own; an earlier type keeps its zone, so a rebreather is never pushed off
/// the body by a cylinder. [sidemountRig] says the rig is sidemount when the items alone do
/// not, as on a dive whose tanks carry sidemount roles but are not linked
/// to the cylinders.
FigureModel composeFigure(
  List<FigureItemInput> items, {
  bool sidemountRig = false,
}) {
  final topLevel = [
    for (final item in items)
      if (!item.isChild) item,
  ];
  final numberById = <String, int>{
    for (var i = 0; i < topLevel.length; i++) topLevel[i].id: i + 1,
  };
  final preferences = {
    for (final item in topLevel) item.id: _Preferences.of(item),
  };
  final context = FigureContext(
    sidemountRig:
        sidemountRig ||
        topLevel.any(
          (item) =>
              FigurePlacement.contributesSidemountRig(
                item.type,
                item.attributes,
              ) ||
              preferences[item.id]!.atTheSide,
        ),
  );
  // Within a type, an item that makes the rig sidemount is placed first, so
  // with a jacket and a sidemount harness in one set the harness takes the
  // back and the drawing matches the sidemount tanks.
  int rigFirst(FigureItemInput item) =>
      FigurePlacement.contributesSidemountRig(item.type, item.attributes)
      ? 0
      : 1;
  // Within a type, a tank with a role or Worn as goes before one with none,
  // so a plain tank listed first cannot take the side the other names.
  int placedFirst(FigureItemInput item) =>
      preferences[item.id]!.tankZones.isEmpty ? 1 : 0;
  final ordered = [...topLevel]
    ..sort((a, b) {
      final byType = equipmentTypeRank(
        a.type,
        kCanonicalTypeOrder,
      ).compareTo(equipmentTypeRank(b.type, kCanonicalTypeOrder));
      if (byType != 0) return byType;
      final byRig = rigFirst(a).compareTo(rigFirst(b));
      if (byRig != 0) return byRig;
      final byPlace = placedFirst(a).compareTo(placedFirst(b));
      return byPlace != 0
          ? byPlace
          : numberById[a.id]!.compareTo(numberById[b.id]!);
    });
  final specs = [
    for (final item in ordered)
      FigurePlacement.forType(
        item.type,
        attributes: item.attributes,
        context: context,
      ),
  ];

  final occupancy = <FigureZone, int>{};
  final zones = List<FigureZone?>.filled(ordered.length, null);
  void claim(int i, Iterable<FigureZone> candidates) {
    final spec = specs[i];
    for (final zone in candidates) {
      if (spec.piecesFor(zone).isEmpty) continue;
      if ((occupancy[zone] ?? 0) + spec.occupies <= zone.capacity) {
        occupancy[zone] = (occupancy[zone] ?? 0) + spec.occupies;
        zones[i] = zone;
        return;
      }
    }
  }

  // Spots the diver moved items to first, then everything else in order,
  // including an item whose chosen spot was already full.
  for (var i = 0; i < ordered.length; i++) {
    final position = preferences[ordered[i].id]!.position;
    if (position != null) claim(i, [position]);
  }
  for (var i = 0; i < ordered.length; i++) {
    if (zones[i] != null) continue;
    claim(i, [...preferences[ordered[i].id]!.tankZones, ...specs[i].zones]);
  }

  final placed = <PlacedItem>[];
  final tray = <PlacedItem>[];
  for (var i = 0; i < ordered.length; i++) {
    final item = ordered[i];
    final spec = specs[i];
    final zone = zones[i];
    final placedItem = PlacedItem(
      number: numberById[item.id]!,
      item: item,
      zone: zone,
      pieceIds: zone == null ? const [] : spec.piecesFor(zone),
      color:
          parseFigureColor(item.attributes[kFigureColorAttribute]) ??
          spec.defaultColor,
    );
    (zone == null ? tray : placed).add(placedItem);
  }
  tray.sort((a, b) => a.number.compareTo(b.number));
  return FigureModel(placed: _mergeDoubles(placed), tray: tray);
}

/// Where the diver put an item: its position on the figure, and for a tank
/// its dive role or, with no role, its Worn as.
class _Preferences {
  const _Preferences(this.position, this.tankZones, {required this.isTank});

  factory _Preferences.of(FigureItemInput item) {
    final isTank = item.type == EquipmentType.tank;
    final tankZones = !isTank
        ? const <FigureZone>[]
        : item.tankRole != null
        ? _zonesForTankRole(item.tankRole!)
        : wornAsZones(item.attributes[EquipmentAttrKeys.wornAs]);
    return _Preferences(
      figurePositionZone(item.attributes[EquipmentAttrKeys.figurePosition]),
      tankZones,
      isTank: isTank,
    );
  }

  final FigureZone? position;
  final List<FigureZone> tankZones;
  final bool isTank;

  /// Whether this is a cylinder put at the diver's side, which makes the
  /// whole rig sidemount: a further cylinder with no place of its own is
  /// then a stage, not a back tank. A stored position a tank has no artwork
  /// for is skipped, as placement skips it.
  bool get atTheSide {
    if (!isTank) return false;
    final first = [
      if (position != null && _tankArtwork.containsKey(position)) position!,
      ...tankZones,
    ].firstOrNull;
    return first == FigureZone.sidemountLeft ||
        first == FigureZone.sidemountRight;
  }
}

/// Every zone a tank has artwork for, which is the same in either rig.
final Map<FigureZone, List<String>> _tankArtwork = FigurePlacement.forType(
  EquipmentType.tank,
).piecesByZone;

List<FigureZone> _zonesForTankRole(TankRole role) => switch (role) {
  TankRole.sidemountLeft => const [
    FigureZone.sidemountLeft,
    FigureZone.sidemountRight,
  ],
  TankRole.sidemountRight => const [
    FigureZone.sidemountRight,
    FigureZone.sidemountLeft,
  ],
  TankRole.stage ||
  TankRole.deco ||
  TankRole.bailout ||
  TankRole.pony ||
  TankRole.suitInflation => const [FigureZone.stageLeft, FigureZone.stageRight],
  TankRole.backGas ||
  TankRole.twinSet ||
  TankRole.diluent ||
  TankRole.oxygenSupply => const [FigureZone.backTank],
};

/// Two tanks in the back tank zone are one manifolded pair: the first draws
/// the doubles piece and the second draws nothing (its label still shows).
/// One tank whose role is Twin Set is that pair logged as one row, so it
/// draws the doubles piece alone (issue #3374).
List<PlacedItem> _mergeDoubles(List<PlacedItem> placed) {
  final backTanks = [
    for (final p in placed)
      if (p.zone == FigureZone.backTank && p.item.type == EquipmentType.tank) p,
  ];
  PlacedItem withPieces(PlacedItem p, List<String> pieceIds) => PlacedItem(
    number: p.number,
    item: p.item,
    zone: p.zone,
    pieceIds: pieceIds,
    color: p.color,
  );
  // A twin set is logged as one cylinder, so one row draws the doubles
  // artwork on its own (issue #3374).
  if (backTanks.length == 1 && backTanks[0].item.tankRole == TankRole.twinSet) {
    return [
      for (final p in placed)
        if (identical(p, backTanks[0]))
          withPieces(p, const ['tank_doubles_back'])
        else
          p,
    ];
  }
  if (backTanks.length < 2) return placed;
  return [
    for (final p in placed)
      if (identical(p, backTanks[0]))
        withPieces(p, const ['tank_doubles_back'])
      else if (identical(p, backTanks[1]))
        withPieces(p, const [])
      else
        p,
  ];
}
