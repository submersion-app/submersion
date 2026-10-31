import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';

enum InventoryGrouping { type, location }

/// What the diver picked on the inventory's options sheet.
class InventoryReportOptions extends Equatable {
  final InventoryGrouping grouping;

  /// One place only, or null for every location.
  final String? locationId;

  /// Off for a customs list that does not show what was paid.
  final bool showPrices;

  const InventoryReportOptions({
    this.grouping = InventoryGrouping.type,
    this.locationId,
    this.showPrices = true,
  });

  @override
  List<Object?> get props => [grouping, locationId, showPrices];
}

/// One heading of the inventory. [type] is set when grouped by gear type and
/// [location] when grouped by a place; neither is the "No location set" group.
class InventoryGroup {
  final EquipmentType? type;
  final EquipmentLocation? location;
  final List<ReportRow> rows;

  /// Largest first, one entry per currency.
  final List<MapEntry<String, double>> subtotals;

  const InventoryGroup({
    this.type,
    this.location,
    required this.rows,
    required this.subtotals,
  });
}

class InventoryReport {
  /// Every printed row, parts included.
  final int itemCount;

  /// Top-level rows with no price. A part with no price says nothing: most
  /// hoses were never bought on their own.
  final int unpricedCount;

  final List<MapEntry<String, double>> totals;
  final List<InventoryGroup> groups;

  const InventoryReport({
    required this.itemCount,
    required this.unpricedCount,
    required this.totals,
    required this.groups,
  });

  bool get isEmpty => groups.isEmpty;
}

/// Builds the inventory from [items], of which only gear owned now counts.
/// [locations] maps an item id to its current place. A part follows its
/// parent: the top-level item decides the group and the location filter, so
/// an assembly is never split across two headings.
InventoryReport buildInventoryReport({
  required List<EquipmentItem> items,
  required Map<String, EquipmentLocation> locations,
  required InventoryReportOptions options,
  required String? diverId,
  required String fallbackCurrency,
}) {
  final owned = [
    for (final item in items)
      if (isOwnedNow(item, diverId)) item,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // Each family is a top-level row and the parts printed under it.
  final families = <List<ReportRow>>[];
  for (final row in arrangeAsTree(owned)) {
    if (row.depth == 0) {
      families.add([row]);
    } else {
      families.last.add(row);
    }
  }
  final kept = [
    for (final family in families)
      if (options.locationId == null ||
          locations[family.first.item.id]?.id == options.locationId)
        family,
  ];

  final groups = switch (options.grouping) {
    InventoryGrouping.type => _byType(kept, fallbackCurrency),
    InventoryGrouping.location => _byLocation(
      kept,
      locations,
      fallbackCurrency,
    ),
  };
  final rows = [for (final family in kept) ...family];
  return InventoryReport(
    itemCount: rows.length,
    unpricedCount: kept
        .where((family) => family.first.item.purchasePrice == null)
        .length,
    totals: _sum(rows, fallbackCurrency),
    groups: groups,
  );
}

List<InventoryGroup> _byType(
  List<List<ReportRow>> families,
  String fallbackCurrency,
) {
  final byType = <EquipmentType, List<ReportRow>>{};
  for (final family in families) {
    (byType[family.first.item.type] ??= []).addAll(family);
  }
  return [
    for (final type in EquipmentType.values)
      if (byType[type] case final rows?)
        InventoryGroup(
          type: type,
          rows: rows,
          subtotals: _sum(rows, fallbackCurrency),
        ),
  ];
}

List<InventoryGroup> _byLocation(
  List<List<ReportRow>> families,
  Map<String, EquipmentLocation> locations,
  String fallbackCurrency,
) {
  final places = <String, EquipmentLocation>{};
  final byPlace = <String, List<ReportRow>>{};
  final nowhere = <ReportRow>[];
  for (final family in families) {
    final place = locations[family.first.item.id];
    if (place == null) {
      nowhere.addAll(family);
    } else {
      places[place.id] = place;
      (byPlace[place.id] ??= []).addAll(family);
    }
  }
  final ordered = places.values.toList()
    ..sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return [
    for (final place in ordered)
      InventoryGroup(
        location: place,
        rows: byPlace[place.id]!,
        subtotals: _sum(byPlace[place.id]!, fallbackCurrency),
      ),
    if (nowhere.isNotEmpty)
      InventoryGroup(rows: nowhere, subtotals: _sum(nowhere, fallbackCurrency)),
  ];
}

List<MapEntry<String, double>> _sum(
  List<ReportRow> rows,
  String fallbackCurrency,
) => sumByCurrency<ReportRow>(
  rows,
  amountOf: (row) => row.item.purchasePrice,
  currencyOf: (row) => row.item.purchaseCurrency,
  fallbackCode: fallbackCurrency,
);
