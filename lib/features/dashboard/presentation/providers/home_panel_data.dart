import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Dives in one calendar month.
@immutable
class MonthCount {
  final int year;
  final int month;
  final int count;

  const MonthCount(this.year, this.month, this.count);
}

/// The twelve months ending with [now]'s month, oldest first, with a month
/// that has no dives as zero (the statistics query skips those).
List<MonthCount> zeroFilledMonths(List<MonthlyDiveCount> raw, DateTime now) {
  final byMonth = {for (final m in raw) (m.year, m.month): m.count};
  return [
    for (var back = 11; back >= 0; back--)
      () {
        final d = DateTime(now.year, now.month - back);
        return MonthCount(d.year, d.month, byMonth[(d.year, d.month)] ?? 0);
      }(),
  ];
}

/// How far through its service interval a clock is, from 0 to 1: the
/// largest of the time elapsed and each usage measure, and 1 once overdue.
double serviceFraction(ServiceClockStatus s) {
  if (s.severity == ServiceClockSeverity.overdue) return 1;
  var fraction = 0.0;
  final due = s.dueDate;
  if (due != null) {
    final span = due.difference(s.anchor).inSeconds;
    if (span > 0) {
      fraction = s.now.difference(s.anchor).inSeconds / span;
    }
  }
  for (final usage in s.usageByUnit.values) {
    if (usage.interval > 0) {
      final f = usage.since / usage.interval;
      if (f > fraction) fraction = f;
    }
  }
  return fraction.clamp(0.0, 1.0);
}

/// One gear item's bar in the gear service panel: its clock furthest
/// through its interval.
@immutable
class GearServiceBar {
  final String itemId;
  final String itemName;
  final ServiceClockStatus status;
  final double fraction;

  const GearServiceBar({
    required this.itemId,
    required this.itemName,
    required this.status,
    required this.fraction,
  });
}

/// The [max] gear items nearest service, overdue first, then fullest.
List<GearServiceBar> gearServiceBars(
  List<EquipmentClocks> clocks, {
  int max = 5,
}) {
  final bars = <GearServiceBar>[];
  for (final e in clocks) {
    if (e.statuses.isEmpty) continue;
    ServiceClockStatus? worst;
    var worstFraction = -1.0;
    for (final s in e.statuses) {
      final f = serviceFraction(s);
      if (f > worstFraction) {
        worst = s;
        worstFraction = f;
      }
    }
    bars.add(
      GearServiceBar(
        itemId: e.item.id,
        itemName: e.item.name,
        status: worst!,
        fraction: worstFraction,
      ),
    );
  }
  bars.sort((a, b) {
    final ao = a.status.severity == ServiceClockSeverity.overdue ? 0 : 1;
    final bo = b.status.severity == ServiceClockSeverity.overdue ? 0 : 1;
    if (ao != bo) return ao.compareTo(bo);
    return b.fraction.compareTo(a.fraction);
  });
  return bars.length <= max ? bars : bars.sublist(0, max);
}

enum ComingDueKind { gear, insurance, certification, document }

/// One dated thing coming due: a gear service, the insurance policy, a
/// certification or a document.
@immutable
class ComingDueItem {
  final ComingDueKind kind;

  /// The gear item, certification or document id; null for insurance.
  final String? id;
  final String name;
  final DateTime due;

  /// A document's type, so one with no title is named by its type. Null
  /// for every other kind.
  final DocumentType? documentType;

  const ComingDueItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.due,
    this.documentType,
  });
}

typedef NamedExpiry = ({String id, String name, DateTime expiry});

/// A document's expiry, with its type for naming an untitled one.
typedef DocumentExpiry = ({
  String id,
  String name,
  DateTime expiry,
  DocumentType type,
});

/// Everything with a date within a year of [now], soonest first, at most
/// [max]. Lapsed gear service always shows; a certification or document
/// that lapsed more than 90 days ago is left out, so an old card nobody
/// renews cannot hold the top of the list for ever.
List<ComingDueItem> comingDueItems({
  required List<EquipmentClocks> clocks,
  required DiverInsurance? insurance,
  required List<NamedExpiry> certifications,
  required List<DocumentExpiry> documents,
  required DateTime now,
  int max = 5,
}) {
  final horizon = DateTime(now.year + 1, now.month, now.day);
  final stale = DateTime(now.year, now.month, now.day - 90);
  final items =
      <ComingDueItem>[
        for (final e in clocks)
          for (final s in e.statuses)
            if (s.dueDate != null)
              ComingDueItem(
                kind: ComingDueKind.gear,
                id: e.item.id,
                name: e.item.name,
                due: s.dueDate!,
              ),
        if (insurance?.providerLabel != null && insurance?.expiryDate != null)
          ComingDueItem(
            kind: ComingDueKind.insurance,
            id: null,
            name: insurance!.providerLabel!,
            due: insurance.expiryDate!,
          ),
        for (final c in certifications)
          ComingDueItem(
            kind: ComingDueKind.certification,
            id: c.id,
            name: c.name,
            due: c.expiry,
          ),
        for (final d in documents)
          ComingDueItem(
            kind: ComingDueKind.document,
            id: d.id,
            name: d.name,
            due: d.expiry,
            documentType: d.type,
          ),
      ].where((i) {
        if (!i.due.isBefore(horizon)) return false;
        return i.kind == ComingDueKind.gear || !i.due.isBefore(stale);
      }).toList();
  // One row per gear item: its soonest clock.
  final seenGear = <String>{};
  items.sort((a, b) => a.due.compareTo(b.due));
  final unique = [
    for (final i in items)
      if (i.kind != ComingDueKind.gear || seenGear.add(i.id!)) i,
  ];
  return unique.length <= max ? unique : unique.sublist(0, max);
}

/// At most [max] values, evenly spaced through [values], keeping both ends.
List<double> downsample(List<double> values, int max) {
  if (values.length <= max || max < 2) return values;
  final step = (values.length - 1) / (max - 1);
  return [for (var i = 0; i < max; i++) values[(i * step).round()]];
}

double? averageOf(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

/// Everything the key numbers panel shows. A null field means its tile has
/// nothing to say and is left out.
@immutable
class HomeKeyNumbers {
  final int careerDives;
  final int careerTimeSeconds;
  final int? divesThisYear;
  final int? timeThisYearSeconds;

  /// Dives per month, the last twelve months, for the dives tile's line.
  final List<double> monthlySeries;

  final int? daysSinceLastDive;
  final String? lastDiveId;
  final String? lastDiveSite;
  final DateTime? lastDiveDate;

  /// Mean SAC (or RMV) over the last ten dives with one, in metric units of
  /// [sacLane], and its change against the ten before.
  final double? avgSac;
  final double? avgSacChange;
  final List<double> sacSeries;
  final GasConsumptionLane sacLane;

  final double? deepestThisYear;
  final double? deepestLastYear;

  /// The dive [deepestThisYear] comes from, and its site (or name), so the
  /// tile can name it and open it.
  final String? deepestDiveId;
  final String? deepestDiveSite;

  final Trip? nextTrip;
  final int? tripChecklistDone;
  final int? tripChecklistTotal;

  final double? avgDepthThisYear;
  final double? avgDepthLastYear;

  final int? species;
  final int? newSpeciesThisYear;

  const HomeKeyNumbers({
    required this.careerDives,
    required this.careerTimeSeconds,
    this.divesThisYear,
    this.timeThisYearSeconds,
    this.monthlySeries = const [],
    this.daysSinceLastDive,
    this.lastDiveId,
    this.lastDiveSite,
    this.lastDiveDate,
    this.avgSac,
    this.avgSacChange,
    this.sacSeries = const [],
    this.sacLane = GasConsumptionLane.rmv,
    this.deepestThisYear,
    this.deepestLastYear,
    this.deepestDiveId,
    this.deepestDiveSite,
    this.nextTrip,
    this.tripChecklistDone,
    this.tripChecklistTotal,
    this.avgDepthThisYear,
    this.avgDepthLastYear,
    this.species,
    this.newSpeciesThisYear,
  });

  bool has(HomeKeyNumber tile) => switch (tile) {
    HomeKeyNumber.dives || HomeKeyNumber.timeUnder => true,
    HomeKeyNumber.lastDive => daysSinceLastDive != null,
    HomeKeyNumber.avgSac => avgSac != null,
    HomeKeyNumber.deepestThisYear => deepestThisYear != null,
    HomeKeyNumber.nextTrip => nextTrip != null,
    HomeKeyNumber.avgDepth => avgDepthThisYear != null,
    HomeKeyNumber.species => species != null && species! > 0,
  };
}
