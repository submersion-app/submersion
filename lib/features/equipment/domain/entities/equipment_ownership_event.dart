import 'package:equatable/equatable.dart';

/// What an [EquipmentOwnershipEvent] records. Stored by [name].
enum EquipmentOwnershipEventKind {
  shared,
  unshared,
  transferred;

  /// Null for a kind this build does not know (written by a newer peer), so
  /// readers can skip it instead of failing.
  static EquipmentOwnershipEventKind? fromName(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// One entry of an item's append-only share and ownership log (issue
/// #2046). For [EquipmentOwnershipEventKind.shared] and `unshared`,
/// [fromDiverId] is the owner at the time and [toDiverId] the sharee; for
/// `transferred`, the old and the new owner. Either is null once that
/// profile is deleted.
class EquipmentOwnershipEvent extends Equatable {
  final String id;
  final String equipmentId;
  final EquipmentOwnershipEventKind kind;
  final String? fromDiverId;
  final String? toDiverId;
  final DateTime occurredAt;

  const EquipmentOwnershipEvent({
    required this.id,
    required this.equipmentId,
    required this.kind,
    this.fromDiverId,
    this.toDiverId,
    required this.occurredAt,
  });

  EquipmentOwnershipEvent copyWith({
    String? id,
    String? equipmentId,
    EquipmentOwnershipEventKind? kind,
    String? fromDiverId,
    String? toDiverId,
    DateTime? occurredAt,
  }) => EquipmentOwnershipEvent(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    kind: kind ?? this.kind,
    fromDiverId: fromDiverId ?? this.fromDiverId,
    toDiverId: toDiverId ?? this.toDiverId,
    occurredAt: occurredAt ?? this.occurredAt,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    kind,
    fromDiverId,
    toDiverId,
    occurredAt,
  ];
}
