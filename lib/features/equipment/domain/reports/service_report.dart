import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';

enum ServiceReportScope { all, trip, item }

/// What the diver picked on the service report's options sheet.
class ServiceReportOptions extends Equatable {
  final ServiceReportScope scope;

  /// Set with [ServiceReportScope.trip].
  final String? tripId;

  /// Set with [ServiceReportScope.item].
  final String? itemId;

  final bool includeHistory;

  /// Off leaves every amount out of the history pages.
  final bool showCosts;

  const ServiceReportOptions({
    this.scope = ServiceReportScope.all,
    this.tripId,
    this.itemId,
    this.includeHistory = true,
    this.showCosts = true,
  });

  @override
  List<Object?> get props => [scope, tripId, itemId, includeHistory, showCosts];
}

/// One clock on the due list. [severity] is the report's verdict, which on a
/// trip report can be worse than [status]'s.
class ServiceDueRow {
  final EquipmentItem item;
  final ServiceClockStatus status;
  final ServiceClockSeverity severity;

  const ServiceDueRow({
    required this.item,
    required this.status,
    required this.severity,
  });
}

class ServiceHistoryRow {
  final ServiceRecord record;

  /// The service kind's name, null when the record has none: the report then
  /// prints the record's category.
  final String? kindName;

  const ServiceHistoryRow({required this.record, this.kindName});
}

class ServiceHistoryBlock {
  final EquipmentItem item;
  final int diveCount;

  /// Newest first.
  final List<ServiceHistoryRow> rows;

  const ServiceHistoryBlock({
    required this.item,
    required this.diveCount,
    required this.rows,
  });
}

class ServiceReport {
  /// The trip or item this report covers, null for all gear.
  final String? scopeLabel;

  /// Clocks, not items, so the summary matches the rows beneath it.
  final int overdue;
  final int dueSoon;
  final int upToDate;

  /// Top-level items with no clock. Parts stay out of it, or hoses would
  /// inflate the number.
  final int noScheduleCount;

  final List<ServiceDueRow> due;
  final List<ServiceHistoryBlock> history;

  /// What a legacy record with a blank currency prints in.
  final String fallbackCurrency;

  const ServiceReport({
    this.scopeLabel,
    required this.fallbackCurrency,
    required this.overdue,
    required this.dueSoon,
    required this.upToDate,
    required this.noScheduleCount,
    required this.due,
    required this.history,
  });
}

/// Builds the report for [gear], which the caller has already narrowed to
/// the chosen scope. [tripEnd] applies the trip page's rule: a date before
/// the trip ends counts as due. Usage clocks are judged as of today, never
/// forecast into the trip.
ServiceReport buildServiceReport({
  required List<EquipmentItem> gear,
  required Map<String, List<ServiceClockStatus>> clocks,
  required Map<String, List<ServiceRecord>> records,
  required Map<String, ServiceKind> kindsById,
  required Map<String, int> diveCounts,
  required ServiceReportOptions options,
  required String fallbackCurrency,
  DateTime? tripEnd,
  String? scopeLabel,
}) {
  ServiceClockSeverity verdict(ServiceClockStatus status) {
    final due = status.dueDate;
    if (status.severity == ServiceClockSeverity.ok &&
        tripEnd != null &&
        due != null &&
        due.isBefore(tripEnd)) {
      return ServiceClockSeverity.dueSoon;
    }
    return status.severity;
  }

  final rows = [
    for (final item in gear)
      for (final status in clocks[item.id] ?? const <ServiceClockStatus>[])
        ServiceDueRow(item: item, status: status, severity: verdict(status)),
  ];
  int count(ServiceClockSeverity severity) =>
      rows.where((row) => row.severity == severity).length;

  final listEveryClock = options.scope == ServiceReportScope.item;
  final due = [
    for (final row in rows)
      if (listEveryClock || row.severity != ServiceClockSeverity.ok) row,
  ]..sort(_byUrgency);

  final ids = {for (final item in gear) item.id};
  final topLevel = gear.where(
    (item) =>
        item.parentEquipmentId == null || !ids.contains(item.parentEquipmentId),
  );

  return ServiceReport(
    scopeLabel: scopeLabel,
    fallbackCurrency: fallbackCurrency,
    overdue: count(ServiceClockSeverity.overdue),
    dueSoon: count(ServiceClockSeverity.dueSoon),
    upToDate: count(ServiceClockSeverity.ok),
    noScheduleCount: topLevel
        .where((item) => clocks[item.id]?.isNotEmpty != true)
        .length,
    due: due,
    history: options.includeHistory
        ? _history(gear, records, kindsById, diveCounts)
        : const [],
  );
}

int _byUrgency(ServiceDueRow a, ServiceDueRow b) {
  final bySeverity = b.severity.index.compareTo(a.severity.index);
  if (bySeverity != 0) return bySeverity;
  final ad = a.status.dueDate, bd = b.status.dueDate;
  if (ad == null && bd != null) return 1;
  if (ad != null && bd == null) return -1;
  final byDate = ad == null ? 0 : ad.compareTo(bd!);
  if (byDate != 0) return byDate;
  return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
}

List<ServiceHistoryBlock> _history(
  List<EquipmentItem> gear,
  Map<String, List<ServiceRecord>> records,
  Map<String, ServiceKind> kindsById,
  Map<String, int> diveCounts,
) {
  final named = [...gear]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [
    for (final row in arrangeAsTree(named))
      if (records[row.item.id] case final own? when own.isNotEmpty)
        ServiceHistoryBlock(
          item: row.item,
          diveCount: diveCounts[row.item.id] ?? 0,
          rows: [
            for (final record in [
              ...own,
            ]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate)))
              ServiceHistoryRow(
                record: record,
                kindName: kindsById[record.serviceKindId]?.name,
              ),
          ],
        ),
  ];
}
