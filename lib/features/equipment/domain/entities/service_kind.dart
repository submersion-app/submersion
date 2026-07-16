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

  ServiceKind copyWith({
    String? id,
    String? diverId,
    String? name,
    List<EquipmentType>? applicableTypes,
    int? defaultIntervalDays,
    int? defaultIntervalDives,
    double? defaultIntervalHours,
    bool? autoAttach,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceKind(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      applicableTypes: applicableTypes ?? this.applicableTypes,
      defaultIntervalDays: defaultIntervalDays ?? this.defaultIntervalDays,
      defaultIntervalDives: defaultIntervalDives ?? this.defaultIntervalDives,
      defaultIntervalHours: defaultIntervalHours ?? this.defaultIntervalHours,
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
