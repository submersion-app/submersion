import 'package:collection/collection.dart' show IterableExtension;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';

/// Ids per query when fetching referenced computers, well below SQLite's
/// bound-variable limit.
const _chunk = 500;

/// [exported] plus every computer a row in [referencing] points at by its
/// `computerId`, for an incremental changeset (issue #4368). A peer that
/// applies a dive or data source without the computer it names has its
/// foreign-key repair clear the link for good, and a computer older than
/// the watermark, or one an earlier apply on the peer failed to keep, is
/// otherwise not sent again until its own clock moves. Resending an
/// unchanged computer is a no-op on the peer. A base ([hlcSince] null)
/// already carries every computer.
Future<List<Map<String, dynamic>>> withReferencedComputers(
  AppDatabase db,
  List<Map<String, dynamic>> exported, {
  required String? hlcSince,
  required List<List<Map<String, dynamic>>> referencing,
}) async {
  if (hlcSince == null) return exported;
  final have = {for (final row in exported) row['id']};
  final missing = {
    for (final rows in referencing)
      for (final row in rows)
        if (row['computerId'] case final String id when !have.contains(id)) id,
  }.toList();
  if (missing.isEmpty) return exported;
  return [
    ...exported,
    for (final chunk in missing.slices(_chunk))
      for (final row in await (db.select(
        db.diveComputers,
      )..where((t) => t.id.isIn(chunk))).get())
        withoutDeviceLocalColumns('diveComputers', row.toJson()),
  ];
}
