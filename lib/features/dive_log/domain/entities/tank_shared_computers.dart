import 'dart:convert';

/// The `dive_tanks.shared_computer_ids` column (v260): the other computers
/// on a consolidated dive that logged this same physical cylinder.
///
/// Consolidation keeps one row for a cylinder two computers both logged
/// (same gas, agreeing pressures, or one transmitter) and attributes it to
/// the computer it merged into. Without this list the folded-in computer
/// loses the cylinder: its analysis scopes gas to its own tanks and reads
/// the dive on whatever it kept alone.
///
/// Stored as a JSON array of computer ids. An empty array
/// ([noSharedComputersRecorded]) means the sharing was recorded and found
/// nobody; null means it was never recorded, which the open-time inference
/// (backfillTankSharedComputers) reads as a cylinder to infer. Null, blank
/// or unreadable text decodes to null.
List<String>? decodeSharedComputerIds(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return null;
    return List.unmodifiable(decoded.whereType<String>());
  } on FormatException {
    return null;
  }
}

/// The stored value of a cylinder whose sharing was recorded and found
/// nobody: a fold, a split, or the open-time inference has handled it.
const String noSharedComputersRecorded = '[]';

/// Inverse of [decodeSharedComputerIds]: null stays null (never recorded),
/// and an empty list is stored as [noSharedComputersRecorded].
String? encodeSharedComputerIds(Iterable<String>? ids) {
  if (ids == null) return null;
  return jsonEncode({...ids}.toList());
}
