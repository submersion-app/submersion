/// The change log label of one editing sitting on a record (issue #4527).
///
/// A sitting changes one record through any number of its cards, and may
/// write other records along the way (a document filed under a dive, an
/// altitude copied to its site). The label stores which record the sitting
/// was opened on, so its History entry stays about that record, and which
/// cards it changed, by id, so the log can name them in the reader's own
/// language: `record_edit:dives:<id>:notes,tags`.
abstract final class RecordEditLabel {
  /// The first part of every label this class writes. The change log's
  /// policy reads it to tell a sitting from any other operation.
  static const prefix = 'record_edit';

  /// The label for a sitting on the record [id] of [table] that changed
  /// [cardIds]. The ids are sorted, so the same sitting always gets the same
  /// label. Throws [ArgumentError] for an empty [id] or one holding the
  /// separator.
  static String encode({
    required String table,
    required String id,
    required Iterable<String> cardIds,
  }) {
    if (id.isEmpty || id.contains(':')) {
      throw ArgumentError.value(id, 'id', 'must be non-empty without ":"');
    }
    final sorted = cardIds.toSet().toList()..sort();
    return '$prefix:$table:$id:${sorted.join(',')}';
  }

  /// The table, record and card ids of a label [encode] wrote, or null for
  /// any other label. A label written before it named its record
  /// (`record_edit:<table>:<cards>`) reads with a null id.
  static ({String table, String? id, List<String> cardIds})? decode(
    String label,
  ) {
    final parts = label.split(':');
    if (parts.length < 3 || parts.length > 4 || parts[0] != prefix) {
      return null;
    }
    final table = parts[1];
    final id = parts.length == 4 ? parts[2] : null;
    final cardIds = parts.last.split(',').where((c) => c.isNotEmpty).toList();
    if (table.isEmpty || id == '' || cardIds.isEmpty) return null;
    return (table: table, id: id, cardIds: cardIds);
  }
}
