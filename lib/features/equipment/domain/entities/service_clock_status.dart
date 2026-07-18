import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

enum ServiceClockSeverity { ok, dueSoon, overdue }

/// A dive's contribution to usage-based clocks.
class DiveUsageSample {
  final DateTime date;
  final int durationSeconds;

  const DiveUsageSample({required this.date, required this.durationSeconds});
}

/// The evaluated state of one service clock at a point in time.
class ServiceClockStatus extends Equatable {
  final ServiceSchedule schedule;
  final ServiceKind kind;
  final DateTime anchor;
  final DateTime? dueDate;
  final int? divesSinceAnchor;
  final int? divesRemaining;
  final double? hoursSinceAnchor;
  final double? hoursRemaining;
  final ServiceClockSeverity severity;
  final DateTime now;

  const ServiceClockStatus({
    required this.schedule,
    required this.kind,
    required this.anchor,
    this.dueDate,
    this.divesSinceAnchor,
    this.divesRemaining,
    this.hoursSinceAnchor,
    this.hoursRemaining,
    required this.severity,
    required this.now,
  });

  /// Days until the date trigger fires; negative when past, null when the
  /// clock has no date trigger.
  int? get daysUntilDue => dueDate?.difference(now).inDays;

  @override
  List<Object?> get props => [
    schedule,
    kind,
    anchor,
    dueDate,
    divesSinceAnchor,
    divesRemaining,
    hoursSinceAnchor,
    hoursRemaining,
    severity,
    now,
  ];
}
