import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';

/// The profiles a gear item is shared with, for its editing sitting (issue
/// #4527, phase 3), through [EquipmentShareRepository].
class EquipmentSharesSharingAdapter extends RecordSharingAdapter<Set<String>> {
  EquipmentSharesSharingAdapter(this._repository);

  final EquipmentShareRepository _repository;

  @override
  Future<Set<String>> read(String recordId) async => {
    for (final share in await _repository.getSharesFor(recordId)) share.diverId,
  };

  /// Refused with no acting profile, or when the repository skipped the
  /// item because it is not the acting profile's. A profile the repository
  /// rejected (deleted on another device while the sitting was open) is
  /// left out, as there is nobody left to share with: the rest is written.
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
    return result.skippedNotOwned == 0;
  }
}
