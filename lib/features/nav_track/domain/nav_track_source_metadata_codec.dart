import 'dart:convert';

// `nav_tracks.source_metadata` (issue #3047): a JSON object of fields a
// route's source exported about the recording, kept exactly as the export
// carried them under its own key names. Nothing interprets them yet.

/// The column value for [metadata]: null when there is nothing to keep, or
/// when JSON cannot hold it (NaN, Infinity, a non-JSON object). Never
/// throws: metadata must not cost the route it describes.
String? encodeNavTrackSourceMetadata(Map<String, Object?>? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  try {
    return jsonEncode(metadata);
  } on JsonUnsupportedObjectError {
    return null;
  }
}

/// The stored [json] as an unmodifiable map, or null when the column is
/// empty or holds anything but a JSON object. Never throws: a value this
/// cannot read must not stop the route from loading.
Map<String, Object?>? decodeNavTrackSourceMetadata(String? json) {
  if (json == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  return _freeze(decoded) as Map<String, Object?>;
}

Object? _freeze(Object? value) => switch (value) {
  Map<String, dynamic>() => Map<String, Object?>.unmodifiable({
    for (final entry in value.entries) entry.key: _freeze(entry.value),
  }),
  List<dynamic>() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};
