import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';

/// How long gear must sit before it counts as idle.
enum IdlePeriod { sixMonths, oneYear, twoYears }

class IdleRow {
  final EquipmentItem item;

  /// Null when the item has never been dived.
  final DateTime? lastDive;

  /// Time since [lastDive], null when [lastDive] is.
  final ({int years, int months})? since;

  const IdleRow({required this.item, this.lastDive, this.since});
}

/// [items] the diver owns and has not dived within [period]: longest idle
/// first, then never-dived gear by name. Never-dived gear counts only once
/// the diver has had it longer than [period], so a purchase from last week
/// is not idle, and nor is gear whose age is unknown.
List<IdleRow> buildIdleGear({
  required List<EquipmentItem> items,
  required Map<String, DateTime> lastDives,
  required String? diverId,
  required IdlePeriod period,
  required DateTime now,
}) {
  final cutoff = _cutoff(period, now);
  final dived = <IdleRow>[];
  final never = <IdleRow>[];
  for (final item in items) {
    if (!isIdleCandidate(item, diverId)) continue;
    final last = lastDives[item.id];
    if (last != null) {
      // A stored dive time is a wall clock flagged UTC, so it is compared by
      // its calendar day, not as an instant against the local cutoff.
      if (DateTime(last.year, last.month, last.day).isBefore(cutoff)) {
        dived.add(
          IdleRow(item: item, lastDive: last, since: _since(last, now)),
        );
      }
    } else {
      final had = item.purchaseDate ?? item.createdAt;
      if (had != null && had.isBefore(cutoff)) never.add(IdleRow(item: item));
    }
  }
  dived.sort((a, b) => a.lastDive!.compareTo(b.lastDive!));
  never.sort((a, b) => compareTextForSort(a.item.name, b.item.name));
  return [...dived, ...never];
}

/// Calendar arithmetic, so a daylight saving change cannot move the line.
DateTime _cutoff(IdlePeriod period, DateTime now) => switch (period) {
  IdlePeriod.sixMonths => DateTime(now.year, now.month - 6, now.day),
  IdlePeriod.oneYear => DateTime(now.year - 1, now.month, now.day),
  IdlePeriod.twoYears => DateTime(now.year - 2, now.month, now.day),
};

({int years, int months}) _since(DateTime from, DateTime now) {
  var months = (now.year - from.year) * 12 + now.month - from.month;
  if (now.day < from.day) months--;
  return (years: months ~/ 12, months: months % 12);
}
