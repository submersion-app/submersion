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

/// One item a retype changed: the item as stored before it and as the
/// retype left it. Undo puts [before] back only while the item still equals
/// [after], so it never reverses an edit or a synced change made since.
class RetypedItem extends Equatable {
  const RetypedItem({required this.before, required this.after});

  final EquipmentItem before;
  final EquipmentItem after;

  String get id => after.id;

  @override
  List<Object?> get props => [before, after];
}

/// What applying a batch of [RetypeCandidate]s did.
class RetypeReceipt extends Equatable {
  const RetypeReceipt({this.retyped = const [], this.failed = 0});

  final List<RetypedItem> retyped;

  /// Items whose write threw, and was rolled back. Items that changed since
  /// they were listed are skipped instead, and counted in neither.
  final int failed;

  @override
  List<Object?> get props => [retyped, failed];
}

/// What undoing a [RetypeReceipt] did.
class RetypeUndoResult extends Equatable {
  const RetypeUndoResult({
    this.restored = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  /// Items put back as they were.
  final int restored;

  /// Items left alone because they changed, or were deleted, since the
  /// retype.
  final int skipped;

  /// Items whose write threw, and was rolled back.
  final int failed;

  @override
  List<Object?> get props => [restored, skipped, failed];
}
