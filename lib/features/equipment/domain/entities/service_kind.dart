import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A type of maintenance a piece of equipment can need (hydro, VIP, ...).
class ServiceKind extends Equatable {
  final String id;
  final String? diverId; // null = built-in / shared
  final String name;

  /// Equipment types this kind suggests for; empty = applies to any type.
  final List<EquipmentType> applicableTypes;
  final int? defaultIntervalDays;
  final int? defaultIntervalDives;
  final double? defaultIntervalHours;
  final bool autoAttach;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceKind({
    required this.id,
    this.diverId,
    required this.name,
    this.applicableTypes = const [],
    this.defaultIntervalDays,
    this.defaultIntervalDives,
    this.defaultIntervalHours,
    this.autoAttach = false,
    this.isBuiltIn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool appliesTo(EquipmentType type) =>
      applicableTypes.isEmpty || applicableTypes.contains(type);

  /// The nullable fields (diverId/defaultInterval*) use the [_undefined]
  /// sentinel so callers can explicitly clear them to null (e.g. promote a
  /// custom kind to shared by clearing diverId, or drop a default interval)
  /// rather than only ever overwriting with a non-null value. Mirrors
  /// [ServiceSchedule.copyWith].
  ServiceKind copyWith({
    String? id,
    Object? diverId = _undefined,
    String? name,
    List<EquipmentType>? applicableTypes,
    Object? defaultIntervalDays = _undefined,
    Object? defaultIntervalDives = _undefined,
    Object? defaultIntervalHours = _undefined,
    bool? autoAttach,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceKind(
      id: id ?? this.id,
      diverId: diverId == _undefined ? this.diverId : diverId as String?,
      name: name ?? this.name,
      applicableTypes: applicableTypes ?? this.applicableTypes,
      defaultIntervalDays: defaultIntervalDays == _undefined
          ? this.defaultIntervalDays
          : defaultIntervalDays as int?,
      defaultIntervalDives: defaultIntervalDives == _undefined
          ? this.defaultIntervalDives
          : defaultIntervalDives as int?,
      defaultIntervalHours: defaultIntervalHours == _undefined
          ? this.defaultIntervalHours
          : defaultIntervalHours as double?,
      autoAttach: autoAttach ?? this.autoAttach,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    applicableTypes,
    defaultIntervalDays,
    defaultIntervalDives,
    defaultIntervalHours,
    autoAttach,
    isBuiltIn,
    createdAt,
    updatedAt,
  ];
}

/// Sentinel distinguishing "argument omitted" from "explicitly set to null" in
/// [ServiceKind.copyWith], so nullable fields can be cleared.
const _undefined = Object();
