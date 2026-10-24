import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/data/services/bulk_tag_service.dart';

/// Puts tags on and takes them off many equipment items at once, with undo
/// (issue #1942): the shared [BulkTagService] over `equipment_tags`.
///
/// Only `equipment_tags` rows change. No equipment row is written or marked
/// pending, so an edit made to an item between Apply and Undo survives both,
/// and a stale whole-item snapshot can never beat a peer's newer edit
/// (#1769).
class BulkEquipmentTagService extends BulkTagService {
  BulkEquipmentTagService(EquipmentTagRepository super.repository)
    : super(itemTable: 'equipment');
}
