import 'dart:math' as math;

import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

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
/// is not idle, and nor is gear whose age is unknown. A part follows its
/// parent while the diver still holds it, and stands alone once it has gone.
/// [index] reaches a part shared between assemblies from each of them.
List<IdleRow> buildIdleGear({
  required List<EquipmentItem> items,
  required Map<String, DateTime> lastDives,
  required String? diverId,
  required IdlePeriod period,
  required DateTime now,
  ComponentsIndex index = ComponentsIndex.empty,
}) {
  final cutoff = _cutoff(period, now);
  final held = {
    for (final item in items)
      if (isOwnedNow(item, diverId)) item.id,
  };
  final dived = <IdleRow>[];
  final never = <IdleRow>[];
  for (final item in items) {
    if (!isIdleCandidate(item, diverId) ||
        held.contains(item.parentEquipmentId)) {
      continue;
    }
    final last = _latestDive(item, items, lastDives, index);
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
  // A whole kit usually shares its last dive, so ties are the common case.
  dived.sort((a, b) {
    final byDate = a.lastDive!.compareTo(b.lastDive!);
    return byDate != 0 ? byDate : compareTextForSort(a.item.name, b.item.name);
  });
  never.sort((a, b) => compareTextForSort(a.item.name, b.item.name));
  return [...dived, ...never];
}

/// When [item] or any part of it was last dived: a part on a dive puts its
/// assembly in the water too, whether or not the assembly was listed.
DateTime? _latestDive(
  EquipmentItem item,
  List<EquipmentItem> items,
  Map<String, DateTime> lastDives,
  ComponentsIndex index,
) {
  DateTime? latest;
  for (final id in withInstalledParts(item.id, items, index: index)) {
    final dive = lastDives[id];
    if (dive != null && (latest == null || dive.isAfter(latest))) latest = dive;
  }
  return latest;
}

DateTime _cutoff(IdlePeriod period, DateTime now) => switch (period) {
  IdlePeriod.sixMonths => _monthsBefore(now, 6),
  IdlePeriod.oneYear => _monthsBefore(now, 12),
  IdlePeriod.twoYears => _monthsBefore(now, 24),
};

/// Calendar arithmetic, so a daylight saving change cannot move the line. A
/// day the earlier month lacks lands on its last day, not in the month after.
DateTime _monthsBefore(DateTime now, int months) {
  final lastDay = DateTime(now.year, now.month - months + 1, 0).day;
  return DateTime(now.year, now.month - months, math.min(now.day, lastDay));
}

({int years, int months}) _since(DateTime from, DateTime now) {
  var months = (now.year - from.year) * 12 + now.month - from.month;
  if (now.day < from.day) months--;
  return (years: months ~/ 12, months: months % 12);
}
