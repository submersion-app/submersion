import 'package:equatable/equatable.dart';

/// A diver profile an equipment item is shared with (issue #2046). The
/// item's owner is never a share.
class EquipmentShare extends Equatable {
  final String id;
  final String equipmentId;
  final String diverId;
  final DateTime createdAt;

  const EquipmentShare({
    required this.id,
    required this.equipmentId,
    required this.diverId,
    required this.createdAt,
  });

  EquipmentShare copyWith({
    String? id,
    String? equipmentId,
    String? diverId,
    DateTime? createdAt,
  }) => EquipmentShare(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    diverId: diverId ?? this.diverId,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  List<Object?> get props => [id, equipmentId, diverId, createdAt];
}
