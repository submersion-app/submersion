import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Links imported equipment items to their tags (issue #1942).
///
/// Equipment imports before tags, so this runs once both have local ids.
/// It links every item of the file that resolved to a local item: one the
/// import created, or an existing one a flagged duplicate was linked to,
/// so re-importing a file unions its tags onto gear the diver already has.
/// A reference with no local tag (the tag was not selected, or the file
/// does not define it) is dropped. A linked tag is widened to equipment.
/// Nothing is ever unlinked. UDDF and the Submersion equipment CSV both
/// reach it through each item map's `tagRefs`.
class ImportEquipmentTagLinker {
  const ImportEquipmentTagLinker({required this.tags, required this.links});

  final TagRepository tags;
  final EquipmentTagRepository links;

  /// [items] are the file's equipment maps. [equipmentIdMapping] and
  /// [tagIdMapping] map the file's ids to local ids; an item with no id is
  /// keyed by its name, whether it was linked to a duplicate or created. A
  /// name two id-less items in the file share cannot say which of them a
  /// mapping stands for, so neither links through it.
  Future<void> link({
    required List<Map<String, dynamic>> items,
    required Map<String, String> equipmentIdMapping,
    required Map<String, String> tagIdMapping,
  }) async {
    final widened = <String>{};
    final idlessNameCounts = countIdlessEquipmentNames(items);
    for (final data in items) {
      final refs = data['tagRefs'];
      if (refs is! List) continue;
      final uddfId = data['uddfId'] as String?;
      final name = data['name'] as String?;
      final key = uddfId ?? (idlessNameCounts[name] == 1 ? name : null);
      final equipmentId = key == null ? null : equipmentIdMapping[key];
      if (equipmentId == null) continue;
      final tagIds = <String>{
        for (final ref in refs.whereType<String>()) ?tagIdMapping[ref],
      }.toList();
      if (tagIds.isEmpty) continue;
      for (final tagId in tagIds) {
        if (widened.add(tagId)) await _widenToEquipment(tagId);
      }
      await links.addTags([equipmentId], tagIds);
    }
  }

  /// How many equipment maps in [items] have no `uddfId` under each
  /// non-empty name. Counted over the whole file, selected or not: an
  /// unselected namesake still makes the name ambiguous.
  static Map<String, int> countIdlessEquipmentNames(
    List<Map<String, dynamic>> items,
  ) {
    final counts = <String, int>{};
    for (final item in items) {
      if (item['uddfId'] != null) continue;
      final name = item['name'];
      if (name is String && name.isNotEmpty) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Widens the exact row. A lookup by name (as getOrCreateTag does) is
  /// unscoped for a tag with no diver and could widen another profile's
  /// namesake instead.
  Future<void> _widenToEquipment(String tagId) async {
    final tag = await tags.getTagById(tagId);
    if (tag == null || tag.appliesTo(TagScope.equipment)) return;
    await tags.updateTag(
      tag.copyWith(scopes: {...tag.scopes, TagScope.equipment}),
    );
  }
}
