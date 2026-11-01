import 'package:equatable/equatable.dart';

import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

/// How much an item has been dived, from every link it has to a dive.
class GearUsageTotals extends Equatable {
  final int diveCount;
  final double hours;

  const GearUsageTotals({required this.diveCount, required this.hours});

  @override
  List<Object?> get props => [diveCount, hours];
}

/// What the cost list ranks by.
enum CostMetric { perDive, perHour, total }

/// One top-level item's cost in one currency, its parts rolled in.
class CostRow {
  final EquipmentItem item;
  final double cost;
  final int diveCount;
  final double hours;

  const CostRow({
    required this.item,
    required this.cost,
    required this.diveCount,
    required this.hours,
  });

  /// Null with no dives, and [perHour] null with no recorded time: a dive
  /// logged with no duration counts a dive but must not divide by zero.
  double? get perDive => diveCount > 0 ? cost / diveCount : null;
  double? get perHour => hours > 0 ? cost / hours : null;
}

/// Everything the section shows for one currency. Amounts are never added
/// across currencies, so a diver with two sees two of these.
class CurrencyCost {
  final String currency;
  final double total;

  /// [total] over the diver's dives, null with none logged.
  final double? perDive;

  /// Every year from the first to the last with spending, so a quiet year in
  /// the middle shows as a gap rather than disappearing.
  final List<({int year, double amount})> byYear;

  /// Priced purchases with no date: in [total], not in [byYear].
  final int undatedPurchases;

  /// Most expensive per dive first.
  final List<CostRow> rows;

  const CurrencyCost({
    required this.currency,
    required this.total,
    required this.perDive,
    required this.byYear,
    required this.undatedPurchases,
    required this.rows,
  });
}

class CostOfOwnership {
  /// Largest total first.
  final List<CurrencyCost> byCurrency;

  /// Top-level items with no cost recorded in any currency.
  final int leftOutCount;

  const CostOfOwnership({required this.byCurrency, required this.leftOutCount});
}

class _Bucket {
  double total = 0;
  int undated = 0;
  final costs = <String, double>{};
  final years = <int, double>{};
}

/// Builds the cost of ownership figures for [items], which may hold more
/// than the diver's own gear: only [isEverOwned] items count. A part's cost
/// rolls into the highest ancestor that also counts, because dives link to
/// the assembly and a first stage on its own would read as never dived.
/// [index] reaches a part shared between assemblies from each of them.
CostOfOwnership buildCostOfOwnership({
  required List<EquipmentItem> items,
  required Map<String, List<ServiceRecord>> recordsByItem,
  required Map<String, GearUsageTotals> usage,
  required int totalDives,
  required String? diverId,
  required String fallbackCurrency,
  ComponentsIndex index = ComponentsIndex.empty,
}) {
  final owned = {
    for (final item in items)
      if (isEverOwned(item, diverId)) item.id: item,
  };

  String rootOf(EquipmentItem item) {
    final seen = <String>{item.id};
    var at = item;
    while (true) {
      final parent = owned[at.parentEquipmentId];
      if (parent == null || !seen.add(parent.id)) return at.id;
      at = parent;
    }
  }

  final fallback = normalizeCurrencyCode(fallbackCurrency, fallback: '');
  final buckets = <String, _Bucket>{};
  _Bucket add(String rootId, String currency, double amount, DateTime? date) {
    final bucket =
        buckets[normalizeCurrencyCode(currency, fallback: fallback)] ??=
            _Bucket();
    bucket.total += amount;
    bucket.costs[rootId] = (bucket.costs[rootId] ?? 0) + amount;
    if (date != null) {
      bucket.years[date.year] = (bucket.years[date.year] ?? 0) + amount;
    }
    return bucket;
  }

  final roots = {for (final item in owned.values) item.id: rootOf(item)};
  for (final item in owned.values) {
    final rootId = roots[item.id]!;
    final price = item.purchasePrice;
    if (price != null && price > 0) {
      final bucket = add(
        rootId,
        item.purchaseCurrency,
        price,
        item.purchaseDate,
      );
      if (item.purchaseDate == null) bucket.undated++;
    }
    for (final record in recordsByItem[item.id] ?? const <ServiceRecord>[]) {
      final cost = record.cost;
      if (cost != null && cost > 0) {
        add(rootId, record.currency, cost, record.serviceDate);
      }
    }
  }

  final costed = {for (final b in buckets.values) ...b.costs.keys};
  final leftOut = roots.values.toSet().difference(costed);

  CostRow rowFor(String rootId, double cost) {
    final used =
        usage[usageSourceOf(
          rootId,
          items,
          index,
          (id) => usage[id]?.diveCount ?? 0,
        )];
    return CostRow(
      item: owned[rootId]!,
      cost: cost,
      diveCount: used?.diveCount ?? 0,
      hours: used?.hours ?? 0,
    );
  }

  final byCurrency = [
    for (final entry in buckets.entries)
      CurrencyCost(
        currency: entry.key,
        total: entry.value.total,
        perDive: totalDives > 0 ? entry.value.total / totalDives : null,
        byYear: _yearRun(entry.value.years),
        undatedPurchases: entry.value.undated,
        rows: sortCostRows([
          for (final cost in entry.value.costs.entries)
            rowFor(cost.key, cost.value),
        ], CostMetric.perDive),
      ),
  ]..sort(_byTotalThenCode);

  return CostOfOwnership(byCurrency: byCurrency, leftOutCount: leftOut.length);
}

/// [rows] ranked by [metric], highest first. A row the metric cannot rate
/// sorts last, by what it cost, and ties fall to the name so the order holds
/// across rebuilds.
List<CostRow> sortCostRows(List<CostRow> rows, CostMetric metric) {
  double? rate(CostRow row) => switch (metric) {
    CostMetric.perDive => row.perDive,
    CostMetric.perHour => row.perHour,
    CostMetric.total => row.cost,
  };
  return [...rows]..sort((a, b) {
    final ra = rate(a), rb = rate(b);
    if (ra == null && rb != null) return 1;
    if (ra != null && rb == null) return -1;
    final byRate = (rb ?? b.cost).compareTo(ra ?? a.cost);
    if (byRate != 0) return byRate;
    return compareTextForSort(a.item.name, b.item.name);
  });
}

List<({int year, double amount})> _yearRun(Map<int, double> years) {
  if (years.isEmpty) return const [];
  final sorted = years.keys.toList()..sort();
  return [
    for (var year = sorted.first; year <= sorted.last; year++)
      (year: year, amount: years[year] ?? 0),
  ];
}

int _byTotalThenCode(CurrencyCost a, CurrencyCost b) {
  final byTotal = b.total.compareTo(a.total);
  return byTotal != 0 ? byTotal : a.currency.compareTo(b.currency);
}
