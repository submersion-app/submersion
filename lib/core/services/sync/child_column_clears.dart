import 'package:drift/drift.dart';

import 'package:submersion/core/services/sync/hlc.dart';

/// Whether a peer's copy of a parent-gated child is newer than the local
/// row, so the nulls it carries are deliberate clears (#2644).
///
/// A copy with no clock never is: it is this device's own base re-applied,
/// or a peer from before v210, and its nulls may only mean "not known
/// there". A local row with no clock was never stamped (every row from
/// before v210, and rows a download inserted), so any stamped copy is newer.
bool isNewerChildCopy({required Hlc? remote, required Hlc? local}) =>
    remote != null && (local == null || remote.compareTo(local) > 0);

/// The keys [remote] sets to null explicitly while [local] holds a value.
/// A key [remote] omits is not a clear: an older peer may simply not know
/// the column (the #474 overlay rule).
Set<String> explicitlyClearedKeys({
  required Map<String, dynamic> remote,
  required Map<String, dynamic> local,
}) => {
  for (final e in remote.entries)
    if (e.value == null && local[e.key] != null) e.key,
};

/// The key Drift's generated `toJson` uses for the SQL column [sqlName]: its
/// camel-case form (`transmitter_serial` becomes `transmitterSerial`). A
/// test pins this for every parent-gated table.
String columnJsonKey(String sqlName) {
  final parts = sqlName.split('_');
  return [
    parts.first,
    for (final part in parts.skip(1))
      if (part.isNotEmpty) '${part[0].toUpperCase()}${part.substring(1)}',
  ].join();
}

/// The columns of [table] a peer's null may clear, keyed by JSON key:
/// nullable, not one of [keyColumns], and not the row clock. Anything else
/// in a payload is ignored, so a malformed copy can neither fail on a
/// NOT NULL column nor move a row's key.
Map<String, String> clearableColumns(
  TableInfo<Table, Object?> table, {
  required List<String> keyColumns,
}) => {
  for (final c in table.$columns)
    if (c.$nullable && c.$name != 'hlc' && !keyColumns.contains(c.$name))
      columnJsonKey(c.$name): c.$name,
};
