import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The tags a UDDF export writes for its equipment items (issue #1942).
class UddfEquipmentTagSource {
  /// Tag ids per exported item.
  final Map<String, List<String>> tagIdsByItem;

  /// Every tag those ids name.
  final List<Tag> tags;

  const UddfEquipmentTagSource({
    this.tagIdsByItem = const {},
    this.tags = const [],
  });
}

/// Loads the tags of [equipmentIds] and resolves each by id.
///
/// By id, not from the current diver's tag list: gear can carry a tag
/// another profile owns, and a reference written without its definition is
/// dropped on import. The same reasoning as the site tags (#1765).
Future<UddfEquipmentTagSource> loadEquipmentTagsForExport(
  EquipmentTagRepository repository,
  List<String> equipmentIds,
) async {
  final tagIdsByItem = await repository.getTagIdsByEquipment(equipmentIds);
  final tagsByItem = await repository.getTagsByEquipment();
  final tags = <String, Tag>{
    for (final id in equipmentIds)
      for (final tag in tagsByItem[id] ?? const <Tag>[]) tag.id: tag,
  };
  return UddfEquipmentTagSource(
    tagIdsByItem: tagIdsByItem,
    tags: tags.values.toList(),
  );
}
