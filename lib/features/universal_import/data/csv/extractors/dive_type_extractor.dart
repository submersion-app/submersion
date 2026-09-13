import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts dive type records from the 'diveTypeIds' lists of transformed
/// CSV rows.
///
/// Each distinct id becomes one record keyed by that id, as the MacDive
/// importer emits them. The importer skips ids that already exist (built-in
/// types, or a custom type from an earlier import) and creates the rest, so
/// a custom type exported from one device exists on the next.
///
/// A type is named as the row's 'diveTypeNames' map (id to name) gives it,
/// which is the name the diver gave it (#1834). An id the row does not name
/// falls back to the display form of the id.
class DiveTypeExtractor implements EntityExtractor<Map<String, dynamic>> {
  const DiveTypeExtractor();

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final types = <Map<String, dynamic>>[];

    for (final row in rows) {
      final ids = row['diveTypeIds'];
      if (ids is! List) continue;
      final names = row['diveTypeNames'];
      for (final id in ids.whereType<String>()) {
        if (id.isEmpty || !seen.add(id)) continue;
        final name = names is Map ? names[id] : null;
        types.add({
          'id': id,
          'uddfId': id,
          'name': name is String ? name : Dive.diveTypeDisplayName(id),
        });
      }
    }

    return types;
  }
}
