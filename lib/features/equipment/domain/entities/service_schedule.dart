import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

/// One service clock on one equipment item. Null intervals inherit the
/// kind's defaults; a clock with no interval in any unit never fires.
class ServiceSchedule extends Equatable {
  final String id;
  final String equipmentId;
  final String serviceKindId;
  final int? intervalDays;
  final int? intervalDives;
  final double? intervalHours;

  /// Per-item overrides for the exposure units that have no column of their
  /// own; a key absent here inherits the kind's map entry.
  final Map<ExposureUnit, double> exposureIntervals;

  /// Per-item default price, overriding the kind's. Null inherits the kind's
  /// value; null currency means "use the diver's default currency".
  final double? defaultCost;
  final String? defaultCurrency;

  /// The diver's baseline date: where the clock counts from, ahead of the
  /// service records of the kind (see `clockAnchorFromServices`).
  final DateTime? anchorDate;

  /// When the diver set [anchorDate]. A record logged after this and dated
  /// on or after the baseline takes the clock back over. Null on baselines
  /// set before v213 and on legacy clocks: any record of the kind wins then.
  final DateTime? anchorSetAt;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceSchedule({
    required this.id,
    required this.equipmentId,
    required this.serviceKindId,
    this.intervalDays,
    this.intervalDives,
    this.intervalHours,
    this.exposureIntervals = const {},
    this.defaultCost,
    this.defaultCurrency,
    this.anchorDate,
    this.anchorSetAt,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The nullable override fields (intervalDays/intervalDives/intervalHours/
  /// defaultCost/defaultCurrency/anchorDate/anchorSetAt) use the [_undefined]
  /// sentinel so callers can explicitly clear them to null (e.g. "Clear
  /// baseline date", reset an interval to inherit the kind default, or drop a
  /// per-item price) rather than only ever overwriting with a non-null value.
  ServiceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? serviceKindId,
    Object? intervalDays = _undefined,
    Object? intervalDives = _undefined,
    Object? intervalHours = _undefined,
    Map<ExposureUnit, double>? exposureIntervals,
    Object? defaultCost = _undefined,
    Object? defaultCurrency = _undefined,
    Object? anchorDate = _undefined,
    Object? anchorSetAt = _undefined,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceSchedule(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      serviceKindId: serviceKindId ?? this.serviceKindId,
      intervalDays: intervalDays == _undefined
          ? this.intervalDays
          : intervalDays as int?,
      intervalDives: intervalDives == _undefined
          ? this.intervalDives
          : intervalDives as int?,
      intervalHours: intervalHours == _undefined
          ? this.intervalHours
          : intervalHours as double?,
      exposureIntervals: exposureIntervals ?? this.exposureIntervals,
      defaultCost: defaultCost == _undefined
          ? this.defaultCost
          : defaultCost as double?,
      defaultCurrency: defaultCurrency == _undefined
          ? this.defaultCurrency
          : defaultCurrency as String?,
      anchorDate: anchorDate == _undefined
          ? this.anchorDate
          : anchorDate as DateTime?,
      anchorSetAt: anchorSetAt == _undefined
          ? this.anchorSetAt
          : anchorSetAt as DateTime?,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// This schedule with [baseline] as its baseline date, stamping
  /// [anchorSetAt] with [now] when the date changes or the diver [picked] it
  /// (so a save that merely leaves the date alone does not let older records
  /// back in front of it, while re-picking a pre-v213 baseline moves it onto
  /// the new rule) and clearing both when [baseline] is null.
  ServiceSchedule withBaseline(
    DateTime? baseline, {
    required DateTime now,
    bool picked = false,
  }) {
    if (baseline == null) return copyWith(anchorDate: null, anchorSetAt: null);
    if (baseline == anchorDate && !picked) return this;
    return copyWith(anchorDate: baseline, anchorSetAt: now);
  }

  /// The effective interval for [unit]: this schedule's override, else the
  /// kind's default. The three v122 units read their columns; the rest read
  /// the map. Null means the unit does not trigger this clock.
  double? intervalFor(ExposureUnit unit, ServiceKind kind) {
    switch (unit) {
      case ExposureUnit.days:
        return (intervalDays ?? kind.defaultIntervalDays)?.toDouble();
      case ExposureUnit.dives:
        return (intervalDives ?? kind.defaultIntervalDives)?.toDouble();
      case ExposureUnit.hours:
        return intervalHours ?? kind.defaultIntervalHours;
      case ExposureUnit.saltHours:
      case ExposureUnit.coldDives:
      case ExposureUnit.o2Hours:
      case ExposureUnit.deepCycles:
      case ExposureUnit.cycles:
        return exposureIntervals[unit] ?? kind.exposureIntervals[unit];
    }
  }

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    serviceKindId,
    intervalDays,
    intervalDives,
    intervalHours,
    exposureIntervals,
    defaultCost,
    defaultCurrency,
    anchorDate,
    anchorSetAt,
    enabled,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
