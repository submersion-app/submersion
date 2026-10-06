import 'package:equatable/equatable.dart';

/// A certification a diver added under any agency, built-in or custom
/// (issue #690). [agencyId] is a built-in enum name or a custom agency id.
class CustomCertificationLevel extends Equatable {
  final String id;

  /// The owner. Only the owner edits, reorders, shares or deletes the level.
  final String diverId;
  final String agencyId;
  final String name;

  /// A ranked rung after the agency's built-in ladder, or a specialty.
  final bool isProgression;

  /// Rank among the agency's custom progression rungs.
  final int sortOrder;

  /// Meaningful only under a built-in agency; under a custom agency the
  /// level follows its agency's visibility.
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomCertificationLevel({
    required this.id,
    required this.diverId,
    required this.agencyId,
    required this.name,
    required this.isProgression,
    this.sortOrder = 0,
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomCertificationLevel copyWith({
    String? id,
    String? diverId,
    String? agencyId,
    String? name,
    bool? isProgression,
    int? sortOrder,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomCertificationLevel(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    agencyId: agencyId ?? this.agencyId,
    name: name ?? this.name,
    isProgression: isProgression ?? this.isProgression,
    sortOrder: sortOrder ?? this.sortOrder,
    isShared: isShared ?? this.isShared,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    agencyId,
    name,
    isProgression,
    sortOrder,
    isShared,
    createdAt,
    updatedAt,
  ];
}
