import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/universal_import/data/models/import_tag_scopes.dart';

/// The tags named in the Submersion equipment CSV's Tags column (issue
/// #1942), in the shape #1848 gave CSV dive tags: one tag map per distinct
/// name for the payload's tag list, and the refs each row's item links to.
///
/// Names are distinct by the key the tags table is unique on (trimmed,
/// case-folded), so "Travel" and "travel" are one tag, spelled as first
/// seen. Each map says it applies to equipment only, so the importer
/// creates a new tag for gear alone and widens an existing tag of the same
/// name (a dive tag, say) instead of adding a second one.
///
/// Not TagExtractor: that splits dive CSV cells on commas, while this
/// column uses the equipment CSV's list codec ('; ' between names, a ';'
/// inside one escaped), so a name holding either survives.
class EquipmentCsvTags {
  final _byKey = <String, Map<String, dynamic>>{};

  /// The refs for one Tags [cell], in order and without repeats. A blank
  /// or missing cell gives none.
  List<String> refsFor(String? cell) {
    if (cell == null) return const [];
    final refs = <String>{};
    for (final raw in splitCsvList(cell)) {
      final name = unescapeCsvListItem(raw).trim();
      if (name.isEmpty) continue;
      final tag = _byKey.putIfAbsent(name.toLowerCase(), () {
        final id = 'csv-tag-${_byKey.length}';
        return {
          'id': id,
          'uddfId': id,
          'name': name,
          for (final MapEntry(key: scope, value: key)
              in importTagScopeKeys.entries)
            key: scope == TagScope.equipment,
        };
      });
      refs.add(tag['uddfId'] as String);
    }
    return refs.toList();
  }

  /// Every tag seen so far, in first-seen order.
  List<Map<String, dynamic>> get tags => [..._byKey.values];
}
