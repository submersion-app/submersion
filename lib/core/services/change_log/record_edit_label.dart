/// The change log label of one editing sitting on a record (issue #4527).
///
/// A sitting changes one record through any number of its cards. The label
/// stores which, by id, so the log can name them in the reader's own
/// language: `record_edit:dives:notes,tags`.
abstract final class RecordEditLabel {
  /// The first part of every label this class writes. The change log's
  /// policy reads it to tell a sitting from any other operation.
  static const prefix = 'record_edit';

  /// The label for a sitting on a record of [table] that changed [cardIds].
  /// The ids are sorted, so the same sitting always gets the same label.
  static String encode({
    required String table,
    required Iterable<String> cardIds,
  }) {
    final sorted = cardIds.toSet().toList()..sort();
    return '$prefix:$table:${sorted.join(',')}';
  }

  /// The table and card ids of a label [encode] wrote, or null for any
  /// other label.
  static ({String table, List<String> cardIds})? decode(String label) {
    final parts = label.split(':');
    if (parts.length != 3 || parts[0] != prefix) return null;
    final table = parts[1];
    final cardIds = parts[2].split(',').where((id) => id.isNotEmpty).toList();
    if (table.isEmpty || cardIds.isEmpty) return null;
    return (table: table, cardIds: cardIds);
  }
}
