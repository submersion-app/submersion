import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/entity_extractor.dart';

/// Extracts dive type records from the 'diveTypeIds' lists of transformed
/// CSV rows.
///
/// Each distinct id becomes one record keyed by that id, as the MacDive
/// importer emits them. The importer skips ids that already exist (built-in
/// types, or a custom type from an earlier import) and creates the rest, so
/// a custom type exported from one device exists on the next.
class DiveTypeExtractor implements EntityExtractor<Map<String, dynamic>> {
  const DiveTypeExtractor();

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final types = <Map<String, dynamic>>[];

    for (final row in rows) {
      final ids = row['diveTypeIds'];
      if (ids is! List) continue;
      for (final id in ids.whereType<String>()) {
        if (id.isEmpty || !seen.add(id)) continue;
        // The export names a type by this same display form of its id.
        types.add({
          'id': id,
          'uddfId': id,
          'name': Dive.diveTypeDisplayName(id),
        });
      }
    }

    return types;
  }
}
