import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// What the composer needs to know about one item. Built from an
/// `EquipmentItem` by `figureInputsFromItems`, or by hand in tests.
class FigureItemInput {
  const FigureItemInput({
    required this.id,
    required this.type,
    required this.name,
    this.attributes = const {},
    this.isChild = false,
    this.tankRole,
  });

  final String id;
  final EquipmentType type;
  final String name;

  /// Catalog attribute values by key (choice keys and, from phase 3, the
  /// `color` hex). Custom attributes are not included.
  final Map<String, String?> attributes;

  /// A parent link or an assembly part: drawn only as its parent.
  final bool isChild;

  /// On a dive, the linked dive tank's role, which places the tank ahead of
  /// the set rule. Null everywhere else.
  final TankRole? tankRole;
}

/// One numbered item on the figure or in the tray.
class PlacedItem {
  const PlacedItem({
    required this.number,
    required this.item,
    required this.zone,
    required this.pieceIds,
    required this.color,
  });

  final int number;
  final FigureItemInput item;

  /// Null for a tray item.
  final FigureZone? zone;

  /// Artwork to draw, one id per view; empty for the tray and for the second
  /// tank of a doubles pair.
  final List<String> pieceIds;

  /// ARGB, the item's own colour or its type default.
  final int color;
}

/// The composed figure: what to draw and what to number.
class FigureModel {
  const FigureModel({required this.placed, required this.tray});

  /// Items with a zone, in placement order.
  final List<PlacedItem> placed;

  /// Items with no zone, in number order.
  final List<PlacedItem> tray;

  int get itemCount => placed.length + tray.length;

  /// Every item in number order, placed and tray together.
  List<PlacedItem> get numbered =>
      [...placed, ...tray]..sort((a, b) => a.number.compareTo(b.number));

  PlacedItem? byId(String id) {
    for (final item in placed) {
      if (item.item.id == id) return item;
    }
    for (final item in tray) {
      if (item.item.id == id) return item;
    }
    return null;
  }
}
