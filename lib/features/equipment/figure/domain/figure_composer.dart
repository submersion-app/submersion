import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The attribute key an item's own colour lives under (phase 3 adds it to
/// the catalog; the composer honours it from the start).
const String kFigureColorAttribute = 'color';

final RegExp _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// `#RRGGBB` to ARGB, or null for anything else. The pattern is checked
/// first because `int.tryParse` accepts a sign, which would turn `#-00001`
/// into a negative colour instead of the type default.
int? parseFigureColor(String? hex) {
  if (hex == null || !_hexColor.hasMatch(hex)) return null;
  return 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}

/// Places [items] on the figure and numbers them (spec sections 4.2 to 4.4).
///
/// Numbers follow the order of [items]; placement walks the canonical type
/// order so the outcome does not depend on the diver's sort setting.
FigureModel composeFigure(List<FigureItemInput> items) {
  final topLevel = [
    for (final item in items)
      if (!item.isChild) item,
  ];
  final numberById = <String, int>{
    for (var i = 0; i < topLevel.length; i++) topLevel[i].id: i + 1,
  };
  final context = FigureContext(
    sidemountRig: topLevel.any(
      (item) =>
          FigurePlacement.contributesSidemountRig(item.type, item.attributes),
    ),
  );
  final ordered = [...topLevel]
    ..sort((a, b) {
      final byType = equipmentTypeRank(
        a.type,
        kCanonicalTypeOrder,
      ).compareTo(equipmentTypeRank(b.type, kCanonicalTypeOrder));
      return byType != 0
          ? byType
          : numberById[a.id]!.compareTo(numberById[b.id]!);
    });

  final occupancy = <FigureZone, int>{};
  final placed = <PlacedItem>[];
  final tray = <PlacedItem>[];
  for (final item in ordered) {
    final spec = FigurePlacement.forType(
      item.type,
      attributes: item.attributes,
      context: context,
    );
    final color =
        parseFigureColor(item.attributes[kFigureColorAttribute]) ??
        spec.defaultColor;
    final zone = _pickZone(item, spec, occupancy);
    final number = numberById[item.id]!;
    if (zone == null) {
      tray.add(
        PlacedItem(
          number: number,
          item: item,
          zone: null,
          pieceIds: const [],
          color: color,
        ),
      );
      continue;
    }
    occupancy[zone] = (occupancy[zone] ?? 0) + spec.occupies;
    placed.add(
      PlacedItem(
        number: number,
        item: item,
        zone: zone,
        pieceIds: spec.piecesFor(zone),
        color: color,
      ),
    );
  }
  tray.sort((a, b) => a.number.compareTo(b.number));
  return FigureModel(placed: _mergeDoubles(placed), tray: tray);
}

/// A dive tank role names its own zones ahead of the set rule; otherwise the
/// first candidate with room wins.
FigureZone? _pickZone(
  FigureItemInput item,
  FigurePlacementSpec spec,
  Map<FigureZone, int> occupancy,
) {
  final candidates = [..._zonesForTankRole(item), ...spec.zones];
  for (final zone in candidates) {
    if ((occupancy[zone] ?? 0) + spec.occupies <= zone.capacity) return zone;
  }
  return null;
}

List<FigureZone> _zonesForTankRole(FigureItemInput item) {
  if (item.type != EquipmentType.tank) return const [];
  return switch (item.tankRole) {
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
    TankRole.pony => const [FigureZone.stageLeft, FigureZone.stageRight],
    TankRole.backGas ||
    TankRole.diluent ||
    TankRole.oxygenSupply => const [FigureZone.backTank],
    null => const [],
  };
}

/// Two tanks in the back tank zone are one manifolded pair: the first draws
/// the doubles piece and the second draws nothing (its label still shows).
List<PlacedItem> _mergeDoubles(List<PlacedItem> placed) {
  final backTanks = [
    for (final p in placed)
      if (p.zone == FigureZone.backTank && p.item.type == EquipmentType.tank) p,
  ];
  if (backTanks.length < 2) return placed;
  PlacedItem withPieces(PlacedItem p, List<String> pieceIds) => PlacedItem(
    number: p.number,
    item: p.item,
    zone: p.zone,
    pieceIds: pieceIds,
    color: p.color,
  );
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
