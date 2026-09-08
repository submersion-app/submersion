import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';

/// A lightweight, serializable snapshot of one overdue service clock: just
/// enough to render the same trigger text as [ServiceClockStatus] without
/// carrying its full [ServiceSchedule]/[ServiceKind] entities. Used to freeze
/// a checklist item's overdue-maintenance list at the moment a diver marks it
/// resolved, so the display survives later changes to the equipment's clocks.
class OverdueServiceEntry extends Equatable {
  final String kindName;
  final DateTime? dueDate;
  final int? divesSinceAnchor;
  final int? divesRemaining;
  final double? hoursSinceAnchor;
  final double? hoursRemaining;

  const OverdueServiceEntry({
    required this.kindName,
    this.dueDate,
    this.divesSinceAnchor,
    this.divesRemaining,
    this.hoursSinceAnchor,
    this.hoursRemaining,
  });

  factory OverdueServiceEntry.fromStatus(ServiceClockStatus status) =>
      OverdueServiceEntry(
        kindName: status.kind.name,
        dueDate: status.dueDate,
        divesSinceAnchor: status.divesSinceAnchor,
        divesRemaining: status.divesRemaining,
        hoursSinceAnchor: status.hoursSinceAnchor,
        hoursRemaining: status.hoursRemaining,
      );

  Map<String, dynamic> toJson() => {
    'kindName': kindName,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'divesSinceAnchor': divesSinceAnchor,
    'divesRemaining': divesRemaining,
    'hoursSinceAnchor': hoursSinceAnchor,
    'hoursRemaining': hoursRemaining,
  };

  factory OverdueServiceEntry.fromJson(Map<String, dynamic> json) =>
      OverdueServiceEntry(
        kindName: json['kindName'] as String,
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['dueDate'] as int),
        divesSinceAnchor: json['divesSinceAnchor'] as int?,
        divesRemaining: json['divesRemaining'] as int?,
        hoursSinceAnchor: (json['hoursSinceAnchor'] as num?)?.toDouble(),
        hoursRemaining: (json['hoursRemaining'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props => [
    kindName,
    dueDate,
    divesSinceAnchor,
    divesRemaining,
    hoursSinceAnchor,
    hoursRemaining,
  ];
}
