import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// An item stored as [EquipmentType.other] whose name says what it is
/// (issue #1886), and what retyping it would write.
class RetypeCandidate extends Equatable {
  const RetypeCandidate({
    required this.item,
    required this.type,
    this.thickness,
  });

  final EquipmentItem item;

  /// The type the item's name reads as.
  final EquipmentType type;

  /// The thickness designation retyping writes, or null when it writes none:
  /// the name states no single thickness, the new type takes none, or the
  /// item already has one.
  final String? thickness;

  @override
  List<Object?> get props => [item, type, thickness];
}

/// One item a retype changed, as Undo needs it.
class RetypedItem extends Equatable {
  const RetypedItem({
    required this.id,
    required this.previousType,
    required this.type,
    required this.addedThickness,
  });

  final String id;
  final EquipmentType previousType;
  final EquipmentType type;

  /// Whether the retype wrote the item's thickness, so Undo removes it.
  final bool addedThickness;

  @override
  List<Object?> get props => [id, previousType, type, addedThickness];
}

/// What applying a batch of [RetypeCandidate]s did.
class RetypeReceipt extends Equatable {
  const RetypeReceipt({this.retyped = const [], this.failed = 0});

  final List<RetypedItem> retyped;

  /// Items whose write threw. Items that changed since they were listed are
  /// skipped instead, and counted in neither.
  final int failed;

  @override
  List<Object?> get props => [retyped, failed];
}
