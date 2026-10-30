import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Reads and writes an equipment item's tags (issue #1942): the
/// `equipment_tags` junction, the equipment twin of `site_tags`.
///
/// The registry-driven [TagLinkRepository] for the equipment scope (#1970),
/// which carries the clockless-child contract: a write marks only the
/// junction rows it inserts pending, tombstones the rows it deletes, and
/// never touches the `equipment` row (#1769). The equipment-named methods
/// below keep the callers that predate it unchanged.
class EquipmentTagRepository extends TagLinkRepository {
  EquipmentTagRepository() : super(domain.TagScope.equipment);

  /// [equipmentId]'s tags, by name.
  Future<List<domain.Tag>> getTagsForEquipment(String equipmentId) =>
      getTagsFor(equipmentId);

  /// Every item's tags, by name, in one query. An item with no tags has no
  /// entry.
  Future<Map<String, List<domain.Tag>>> getTagsByEquipment() => getTagsByItem();

  /// Raw tag ids per item for [equipmentIds], oldest link first, for bulk
  /// edit snapshots and exports. An item with no tags has no entry.
  Future<Map<String, List<String>>> getTagIdsByEquipment(
    List<String> equipmentIds,
  ) => getTagIdsByItem(equipmentIds);

  /// How many of [equipmentIds] carry each tag, keyed by tag id: the
  /// tri-state seed of the bulk tag editor.
  Future<Map<String, int>> tagCountsForEquipment(List<String> equipmentIds) =>
      tagCountsFor(equipmentIds);

  /// Deletes and tombstones every tag link of [equipmentId], for
  /// `EquipmentRepository.deleteEquipment`. Runs inside the caller's
  /// transaction and does not notify.
  Future<void> deleteLinksForEquipment(String equipmentId) =>
      deleteLinksFor([equipmentId]);
}
