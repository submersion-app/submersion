import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';

/// One rendered run of gear.
///
/// [type] is the header to draw, or null when the arrangement asked for no
/// grouping, in which case there is exactly one group holding everything.
@immutable
class EquipmentGroup {
  final EquipmentType? type;
  final List<EquipmentItem> items;

  const EquipmentGroup({required this.type, required this.items});
}

/// Sorts far enough in the future that undated gear lands last on an
/// ascending sort.
final DateTime _noDate = DateTime.utc(9999);

/// Groups and orders [items] for display.
///
/// [typeLabel] resolves a type to the string the reader sees. Injecting it
/// rather than importing `AppLocalizations` keeps this file free of Flutter
/// widget dependencies and lets the PDF template, which has no localizations
/// in scope, reuse the identical logic by passing `(t) => t.displayName`.
///
/// The input list is never mutated.
List<EquipmentGroup> arrangeEquipment(
  List<EquipmentItem> items,
  EquipmentArrangement arrangement, {
  required String Function(EquipmentType) typeLabel,
}) {
  if (items.isEmpty) return const [];

  final orderingByType = arrangement.typeOrder != EquipmentTypeOrder.none;
  // Grouping is meaningless without a type ordering: headers in an arbitrary
  // sequence would recreate the very complaint this feature answers.
  final grouped = arrangement.groupByType && orderingByType;

  // Resolved once per call rather than per comparison. When the diver is not
  // grouping, compareTypes runs inside the ITEM comparator, so it is called
  // O(n log n) times across the whole inventory: resolving and lowercasing a
  // label in there allocated two Strings on every one of them, which is
  // exactly the large-inventory case #1576 is about. At most 28 entries.
  final rankTable = equipmentTypeRankTable(arrangement.typeOrder);
  final lowerLabels = <EquipmentType, String>{};
  String lowerLabel(EquipmentType type) =>
      lowerLabels[type] ??= typeLabel(type).toLowerCase();

  int compareTypes(EquipmentType a, EquipmentType b) {
    if (a == b) return 0;
    final int ordered;
    if (rankTable != null) {
      ordered = equipmentTypeRank(
        a,
        rankTable,
      ).compareTo(equipmentTypeRank(b, rankTable));
    } else {
      // Alphabetical, on what the reader actually sees.
      final byLabel = lowerLabel(a).compareTo(lowerLabel(b));
      // Fall back to the stable enum name so two types sharing a translation
      // still order consistently.
      ordered = byLabel != 0 ? byLabel : a.name.compareTo(b.name);
    }
    // "Toe to head" (#1486) and "descending by Head to Toe" (#1576). Applied
    // to the type axis only, so reversing the headings leaves the gear inside
    // each heading in the order the item sort asked for.
    return arrangement.typeOrderDescending ? -ordered : ordered;
  }

  // Same reasoning as the type labels above: a name is lowercased twice per
  // comparison (once for the name sort, once for the tie-break that every
  // sort field falls through to), so the comparator allocated up to four
  // Strings on each of O(n log n) calls. Keyed by id, one entry per item.
  final lowerNames = <String, String>{};
  String lowerName(EquipmentItem item) =>
      lowerNames[item.id] ??= item.name.toLowerCase();

  int compareItems(EquipmentItem a, EquipmentItem b) {
    int primary;
    switch (arrangement.itemSortField) {
      case EquipmentItemSortField.name:
        primary = lowerName(a).compareTo(lowerName(b));
      case EquipmentItemSortField.purchaseDate:
        primary = _compareDates(a.purchaseDate, b.purchaseDate);
      case EquipmentItemSortField.dateAdded:
        primary = _compareDates(a.createdAt, b.createdAt);
      case EquipmentItemSortField.lastServiceDate:
        primary = _compareDates(a.lastServiceDate, b.lastServiceDate);
    }
    if (arrangement.itemSortDirection == SortDirection.descending) {
      primary = -primary;
    }
    // Undated gear sorts last in BOTH directions, so flipping the direction
    // never buries the dated items the diver was looking for. Applied after
    // the inversion, which is why it cannot live inside _compareDates.
    final aMissing = _isMissing(a, arrangement.itemSortField);
    final bMissing = _isMissing(b, arrangement.itemSortField);
    if (aMissing != bMissing) return aMissing ? 1 : -1;
    if (primary != 0) return primary;
    // List.sort is not stable in Dart, so equal-ranked items would reorder
    // between rebuilds and flicker. Tie-break to a total order, never
    // inverted, so the fallback stays predictable in both directions.
    final byName = lowerName(a).compareTo(lowerName(b));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  if (!grouped) {
    final flat = List<EquipmentItem>.from(items);
    flat.sort((a, b) {
      if (orderingByType) {
        final byType = compareTypes(a.type, b.type);
        if (byType != 0) return byType;
      }
      return compareItems(a, b);
    });
    return [EquipmentGroup(type: null, items: List.unmodifiable(flat))];
  }

  final buckets = <EquipmentType, List<EquipmentItem>>{};
  for (final item in items) {
    buckets.putIfAbsent(item.type, () => []).add(item);
  }
  final types = buckets.keys.toList()..sort(compareTypes);
  return [
    for (final type in types)
      EquipmentGroup(
        type: type,
        items: List.unmodifiable(buckets[type]!..sort(compareItems)),
      ),
  ];
}

int _compareDates(DateTime? a, DateTime? b) =>
    (a ?? _noDate).compareTo(b ?? _noDate);

bool _isMissing(EquipmentItem item, EquipmentItemSortField field) =>
    switch (field) {
      EquipmentItemSortField.name => false,
      EquipmentItemSortField.purchaseDate => item.purchaseDate == null,
      EquipmentItemSortField.dateAdded => item.createdAt == null,
      EquipmentItemSortField.lastServiceDate => item.lastServiceDate == null,
    };
