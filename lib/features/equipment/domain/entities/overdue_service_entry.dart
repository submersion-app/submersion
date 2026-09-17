import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

/// A lightweight, serializable snapshot of one service clock: just enough to
/// render the same trigger text as [ServiceClockStatus] without carrying its
/// full [ServiceSchedule]/[ServiceKind] entities. Used to freeze a checklist
/// item's maintenance list (every configured clock, not only overdue ones)
/// at the moment a diver marks it resolved, so the display survives later
/// changes to the equipment's clocks.
class OverdueServiceEntry extends Equatable {
  final String kindName;
  final ServiceClockSeverity severity;
  final DateTime? dueDate;
  final Map<ExposureUnit, ClockUsage> usageByUnit;

  /// The v122 spelling, kept for entries frozen before [usageByUnit]
  /// existed; still populated by [fromStatus] so a rollback to an older
  /// build can still read a freshly frozen entry.
  final int? divesSinceAnchor;
  final int? divesRemaining;
  final double? hoursSinceAnchor;
  final double? hoursRemaining;

  const OverdueServiceEntry({
    required this.kindName,
    this.severity = ServiceClockSeverity.overdue,
    this.dueDate,
    this.usageByUnit = const {},
    this.divesSinceAnchor,
    this.divesRemaining,
    this.hoursSinceAnchor,
    this.hoursRemaining,
  });

  factory OverdueServiceEntry.fromStatus(ServiceClockStatus status) =>
      OverdueServiceEntry(
        kindName: status.kind.name,
        severity: status.severity,
        dueDate: status.dueDate,
        usageByUnit: status.usageByUnit,
        divesSinceAnchor: status.divesSinceAnchor,
        divesRemaining: status.divesRemaining,
        hoursSinceAnchor: status.hoursSinceAnchor,
        hoursRemaining: status.hoursRemaining,
      );

  Map<String, dynamic> toJson() => {
    'kindName': kindName,
    'severity': severity.name,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'usageByUnit': {
      for (final entry in usageByUnit.entries)
        entry.key.dbValue: {
          'interval': entry.value.interval,
          'since': entry.value.since,
        },
    },
    'divesSinceAnchor': divesSinceAnchor,
    'divesRemaining': divesRemaining,
    'hoursSinceAnchor': hoursSinceAnchor,
    'hoursRemaining': hoursRemaining,
  };

  /// Snapshots frozen before [severity]/[usageByUnit] existed carry neither
  /// key; they only ever held overdue clocks, so that is the correct
  /// fallback severity, and an empty usage map falls back to the legacy
  /// dives/hours fields via [formatServiceTriggerText].
  factory OverdueServiceEntry.fromJson(Map<String, dynamic> json) =>
      OverdueServiceEntry(
        kindName: json['kindName'] as String,
        severity: json['severity'] == null
            ? ServiceClockSeverity.overdue
            : ServiceClockSeverity.values.byName(json['severity'] as String),
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['dueDate'] as int),
        usageByUnit: _decodeUsageByUnit(json['usageByUnit']),
        divesSinceAnchor: json['divesSinceAnchor'] as int?,
        divesRemaining: json['divesRemaining'] as int?,
        hoursSinceAnchor: (json['hoursSinceAnchor'] as num?)?.toDouble(),
        hoursRemaining: (json['hoursRemaining'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [
    kindName,
    severity,
    dueDate,
    usageByUnit,
    divesSinceAnchor,
    divesRemaining,
    hoursSinceAnchor,
    hoursRemaining,
  ];
}

/// Unknown units and unreadable entries are dropped rather than thrown on: a
/// snapshot frozen by a newer peer may carry a unit this build does not
/// know, mirroring [decodeExposureIntervals]'s tolerance for the same case.
Map<ExposureUnit, ClockUsage> _decodeUsageByUnit(Object? raw) {
  if (raw is! Map) return const {};
  final out = <ExposureUnit, ClockUsage>{};
  for (final entry in raw.entries) {
    final unit = ExposureUnit.fromDbValue(entry.key.toString());
    final usage = entry.value;
    if (unit == null || usage is! Map) continue;
    final interval = usage['interval'];
    final since = usage['since'];
    if (interval is! num || since is! num) continue;
    out[unit] = ClockUsage(
      interval: interval.toDouble(),
      since: since.toDouble(),
    );
  }
  return out;
}
