import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';

/// Who a trip or a site is shared with, for its editing sitting (issue
/// #4527, phase 3), through [ItemSharesRepository].
class ItemSharesSharingAdapter implements RecordSharingAdapter<ItemSharing> {
  ItemSharesSharingAdapter(this._repository, this._kind);

  final ItemSharesRepository _repository;
  final SharedItemKind _kind;

  @override
  Future<ItemSharing> read(String recordId) =>
      _repository.sharingOf(_kind, recordId);

  @override
  Future<bool> write(
    String recordId,
    ItemSharing sharing, {
    required String? actingDiverId,
  }) => _repository.setSharing(
    _kind,
    recordId,
    sharing,
    actingDiverId: actingDiverId,
  );
}
