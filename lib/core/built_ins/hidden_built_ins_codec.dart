import 'dart:convert';

/// Encodes the hidden built-in ids for `diver_settings.hidden_built_in_ids`
/// (issue #401): a JSON object of catalog key to id list. Keys and ids are
/// sorted and empty catalogs omitted, so equal contents always encode equal
/// (the settings save compares encoded columns). Nothing hidden is null.
String? encodeHiddenBuiltIns(Map<String, Set<String>> hidden) {
  final keys = [
    for (final entry in hidden.entries)
      if (entry.value.isNotEmpty) entry.key,
  ]..sort();
  if (keys.isEmpty) return null;
  return jsonEncode({
    for (final key in keys) key: hidden[key]!.toList()..sort(),
  });
}

/// Reads what [encodeHiddenBuiltIns] wrote. Never throws: null, empty,
/// malformed or wrongly typed input reads as nothing hidden, and entries that
/// are not a list of strings are skipped. Keys this version does not know are
/// kept, so a save does not drop what a newer version synced in.
Map<String, Set<String>> decodeHiddenBuiltIns(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const {};
  }
  if (decoded is! Map) return const {};
  return {
    for (final entry in decoded.entries)
      if (entry.key is String && entry.value is List)
        if (_ids(entry.value as List) case final ids when ids.isNotEmpty)
          entry.key as String: ids,
  };
}

Set<String> _ids(List<dynamic> values) => {
  for (final value in values)
    if (value is String && value.isNotEmpty) value,
};
