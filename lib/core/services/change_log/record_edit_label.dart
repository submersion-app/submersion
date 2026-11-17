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
  /// label. An empty [id], or one holding the separator, is left out: the
  /// label then names only the cards, and the sitting is not pinned to its
  /// record, since logging must never stop a save.
  static String encode({
    required String table,
    required String id,
    required Iterable<String> cardIds,
  }) {
    final sorted = cardIds.toSet().toList()..sort();
    final cards = sorted.join(',');
    if (id.isEmpty || id.contains(':')) return '$prefix:$table:$cards';
    return '$prefix:$table:$id:$cards';
  }

  /// The table, record and card ids of a label [encode] wrote, or null for
  /// any other label. A label written before it named its record
  /// (`record_edit:<table>:<cards>`) reads with a null id, and one that named
  /// no card with an empty list.
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
    if (table.isEmpty || id == '') return null;
    return (table: table, id: id, cardIds: cardIds);
  }
}
