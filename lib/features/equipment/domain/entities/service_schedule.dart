import 'package:equatable/equatable.dart';

/// One service clock on one equipment item. Null intervals inherit the
/// kind's defaults; a clock with all three intervals null never fires.
class ServiceSchedule extends Equatable {
  final String id;
  final String equipmentId;
  final String serviceKindId;
  final int? intervalDays;
  final int? intervalDives;
  final double? intervalHours;
  final DateTime? anchorDate;
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
    this.anchorDate,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The nullable override fields (intervalDays/intervalDives/intervalHours/
  /// anchorDate) use the [_undefined] sentinel so callers can explicitly clear
  /// them to null (e.g. "Clear baseline date" or reset an interval to inherit
  /// the kind default) rather than only ever overwriting with a non-null value.
  ServiceSchedule copyWith({
    String? id,
    String? equipmentId,
    String? serviceKindId,
    Object? intervalDays = _undefined,
    Object? intervalDives = _undefined,
    Object? intervalHours = _undefined,
    Object? anchorDate = _undefined,
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
      anchorDate: anchorDate == _undefined
          ? this.anchorDate
          : anchorDate as DateTime?,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    serviceKindId,
    intervalDays,
    intervalDives,
    intervalHours,
    anchorDate,
    enabled,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
