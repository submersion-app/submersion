import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Bound variables per statement, well under SQLite's 32,766 ceiling.
const int _chunkSize = 900;

/// Which of [ids] still have a row in [table], keyed by its `id` column.
/// For a restore that re-inserts rows under their old ids: a row whose
/// foreign-key target was deleted since has to be skipped or unlinked, or
/// the insert fails.
Future<Set<String>> existingRowIds(
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  Iterable<String> ids,
) async {
  final all = ids.toSet().toList();
  final found = <String>{};
  for (var start = 0; start < all.length; start += _chunkSize) {
    final chunk = all.sublist(
      start,
      start + _chunkSize < all.length ? start + _chunkSize : all.length,
    );
    final rows = await db
        .customSelect(
          'SELECT id FROM ${table.actualTableName} WHERE id IN '
          '(${List.filled(chunk.length, '?').join(', ')})',
          variables: [for (final id in chunk) Variable.withString(id)],
        )
        .get();
    found.addAll([for (final r in rows) r.read<String>('id')]);
  }
  return found;
}
