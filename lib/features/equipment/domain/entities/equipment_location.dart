import 'package:equatable/equatable.dart';

/// What kind of place an [EquipmentLocation] is. Stored by [name]. The
/// order is the heading order when the Equipment page groups by location.
enum EquipmentLocationKind {
  storage,
  diveCenter,
  serviceShop,
  person,
  other;

  /// A name this build does not know (written by a newer peer), or none,
  /// reads as [other] rather than failing.
  static EquipmentLocationKind fromName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return other;
  }
}

/// One of a diver's named places where gear can be: a shelf, a dive center,
/// a shop, a friend. Archived places leave the picker but stay in history.
class EquipmentLocation extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final EquipmentLocationKind kind;

  /// The saved dive center this place stands for, if any (issue #3623).
  final String? diveCenterId;

  /// The buddy this place stands for, if any (issue #3790).
  final String? buddyId;
  final String notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentLocation({
    required this.id,
    this.diverId,
    required this.name,
    required this.kind,
    this.diveCenterId,
    this.buddyId,
    this.notes = '',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  EquipmentLocation copyWith({
    String? id,
    String? diverId,
    String? name,
    EquipmentLocationKind? kind,
    String? diveCenterId,
    bool clearDiveCenterId = false,
    String? buddyId,
    bool clearBuddyId = false,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EquipmentLocation(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    diveCenterId: clearDiveCenterId ? null : diveCenterId ?? this.diveCenterId,
    buddyId: clearBuddyId ? null : buddyId ?? this.buddyId,
    notes: notes ?? this.notes,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    kind,
    diveCenterId,
    buddyId,
    notes,
    isArchived,
    createdAt,
    updatedAt,
  ];
}
