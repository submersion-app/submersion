import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';

/// The profiles a gear item is shared with, for its editing sitting (issue
/// #4527, phase 3), through [EquipmentShareRepository].
class EquipmentSharesSharingAdapter
    implements RecordSharingAdapter<Set<String>> {
  EquipmentSharesSharingAdapter(this._repository);

  final EquipmentShareRepository _repository;

  @override
  Future<Set<String>> read(String recordId) async => {
    for (final share in await _repository.getSharesFor(recordId)) share.diverId,
  };

  /// Refused with no acting profile, or when the repository skipped the
  /// item (not the acting profile's) or rejected a profile (the item's
  /// owner, or one that no longer exists): the sharing would not be what
  /// the diver chose.
  @override
  Future<bool> write(
    String recordId,
    Set<String> sharing, {
    required String? actingDiverId,
  }) async {
    if (actingDiverId == null) return false;
    final result = await _repository.setShares(
      equipmentId: recordId,
      diverIds: sharing,
      actingDiverId: actingDiverId,
    );
    return result.skippedNotOwned == 0 && result.rejected == 0;
  }
}
