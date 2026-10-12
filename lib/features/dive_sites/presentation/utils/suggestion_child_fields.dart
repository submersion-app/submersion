import 'package:flutter/foundation.dart';

/// The child lists a reader's suggestion proposes (issue #2567): only those
/// the reader changed, by name, so accepting it re-clocks nothing that
/// stayed as it was.
Map<String, Object?> suggestionChildFields({
  required Set<String> originalTypeIds,
  required Set<String> selectedTypeIds,
  required Map<String, String> typeNames,
  required Set<String> originalTagIds,
  required List<({String id, String name})> selectedTags,
}) => {
  if (!setEquals(originalTypeIds, selectedTypeIds))
    'siteTypes': [for (final id in selectedTypeIds) ?typeNames[id]],
  if (!setEquals(originalTagIds, {for (final t in selectedTags) t.id}))
    'tags': [for (final t in selectedTags) t.name],
};
