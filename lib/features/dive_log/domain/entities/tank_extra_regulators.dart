import 'dart:convert';

/// The `dive_tanks.extra_regulator_ids` column (v312, issue #3375): the
/// regulators on a cylinder after the first, which stays in
/// `regulator_equipment_id`. A twin valve or a manifolded twin set carries
/// two or more, and every one of them is on the dive.
///
/// Stored as a JSON array of equipment ids, or null for none (never `[]`).
/// Null, blank, `[]` or unreadable text decodes to an empty list, so a bad
/// value from a peer reads as no extras rather than failing the read.
List<String> decodeExtraRegulatorIds(String? text) {
  if (text == null || text.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return const [];
    return List.unmodifiable(decoded.whereType<String>());
  } on FormatException {
    return const [];
  }
}

/// Inverse of [decodeExtraRegulatorIds]: blanks and repeats dropped, and
/// null when nothing is left.
String? encodeExtraRegulatorIds(Iterable<String> ids) {
  final kept = {
    for (final id in ids)
      if (id.trim().isNotEmpty) id,
  };
  return kept.isEmpty ? null : jsonEncode(kept.toList());
}

/// A tank's regulators in the form every write stores: no blank id, no id
/// twice, none of the extras equal to the first, and no extras without a
/// first (the first extra moves up).
({String? first, List<String> extras}) normalizeTankRegulators(
  String? first,
  Iterable<String> extras,
) {
  final ids = {
    for (final id in [?first, ...extras])
      if (id.trim().isNotEmpty) id,
  }.toList();
  if (ids.isEmpty) return (first: null, extras: const []);
  return (first: ids.first, extras: List.unmodifiable(ids.skip(1)));
}
