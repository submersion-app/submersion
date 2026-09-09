import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

enum ServiceClockSeverity { ok, dueSoon, overdue }

/// One dive's contribution to usage-based clocks: what the item was exposed
/// to, in storage units. Everything beyond date and duration is optional so
/// a dive logged without a profile or water type still counts a dive and
/// its hours.
class EquipmentExposureSample extends Equatable {
  final DateTime date;
  final int durationSeconds;
  final DiveMode diveMode;

  /// Metres, from the profile when available, else the dive header.
  final double? maxDepth;

  /// Celsius, the profile minimum when available, else the dive header.
  final double? minTemperature;
  final WaterType? waterType;

  /// The highest O2 fraction (0 to 1) this item was in contact with on the
  /// dive, or null when the link path carries no gas (a mask, a fin).
  final double? contactO2Fraction;

  const EquipmentExposureSample({
    required this.date,
    required this.durationSeconds,
    this.diveMode = DiveMode.oc,
    this.maxDepth,
    this.minTemperature,
    this.waterType,
    this.contactO2Fraction,
  });

  double get durationHours => durationSeconds / 3600.0;

  @override
  List<Object?> get props => [
    date,
    durationSeconds,
    diveMode,
    maxDepth,
    minTemperature,
    waterType,
    contactO2Fraction,
  ];
}

/// The v122 name. Every field beyond date and duration is optional, so
/// existing call sites and tests keep compiling.
typedef DiveUsageSample = EquipmentExposureSample;

/// One unit's progress on a clock: the configured interval and the amount
/// accrued since the anchor, both in that unit.
class ClockUsage extends Equatable {
  final double interval;
  final double since;

  const ClockUsage({required this.interval, required this.since});

  double get remaining => interval - since;

  @override
  List<Object?> get props => [interval, since];
}

/// The evaluated state of one service clock at a point in time.
class ServiceClockStatus extends Equatable {
  final ServiceSchedule schedule;
  final ServiceKind kind;
  final DateTime anchor;
  final DateTime? dueDate;

  /// Progress per configured usage unit. Units with no interval are absent.
  final Map<ExposureUnit, ClockUsage> usageByUnit;
  final ServiceClockSeverity severity;
  final DateTime now;

  /// [divesSinceAnchor], [divesRemaining], [hoursSinceAnchor] and
  /// [hoursRemaining] are the v122 spelling; they fold into [usageByUnit].
  /// Pass either form, not both for the same unit.
  ServiceClockStatus({
    required this.schedule,
    required this.kind,
    required this.anchor,
    this.dueDate,
    int? divesSinceAnchor,
    int? divesRemaining,
    double? hoursSinceAnchor,
    double? hoursRemaining,
    Map<ExposureUnit, ClockUsage> usageByUnit = const {},
    required this.severity,
    required this.now,
  }) : usageByUnit = _fold(
         usageByUnit,
         divesSinceAnchor: divesSinceAnchor,
         divesRemaining: divesRemaining,
         hoursSinceAnchor: hoursSinceAnchor,
         hoursRemaining: hoursRemaining,
       );

  static Map<ExposureUnit, ClockUsage> _fold(
    Map<ExposureUnit, ClockUsage> given, {
    int? divesSinceAnchor,
    int? divesRemaining,
    double? hoursSinceAnchor,
    double? hoursRemaining,
  }) {
    final out = Map<ExposureUnit, ClockUsage>.from(given);
    if (divesSinceAnchor != null && divesRemaining != null) {
      out.putIfAbsent(
        ExposureUnit.dives,
        () => ClockUsage(
          interval: (divesSinceAnchor + divesRemaining).toDouble(),
          since: divesSinceAnchor.toDouble(),
        ),
      );
    }
    if (hoursSinceAnchor != null && hoursRemaining != null) {
      out.putIfAbsent(
        ExposureUnit.hours,
        () => ClockUsage(
          interval: hoursSinceAnchor + hoursRemaining,
          since: hoursSinceAnchor,
        ),
      );
    }
    return Map.unmodifiable(out);
  }

  int? get divesSinceAnchor => usageByUnit[ExposureUnit.dives]?.since.round();
  int? get divesRemaining => usageByUnit[ExposureUnit.dives]?.remaining.round();
  double? get hoursSinceAnchor => usageByUnit[ExposureUnit.hours]?.since;
  double? get hoursRemaining => usageByUnit[ExposureUnit.hours]?.remaining;

  /// Days until the date trigger fires; negative when past, null when the
  /// clock has no date trigger.
  int? get daysUntilDue => dueDate?.difference(now).inDays;

  @override
  List<Object?> get props => [
    schedule,
    kind,
    anchor,
    dueDate,
    usageByUnit,
    severity,
    now,
  ];
}
