import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';

/// Rows the cover and practice tests share: what a database says about
/// one record's sync state.
Future<List<String>> pendingRecords(AppDatabase db, String entityType) async {
  final rows = await db
      .customSelect(
        'SELECT record_id FROM sync_records '
        "WHERE entity_type = ? AND sync_status = 'pending'",
        variables: [Variable.withString(entityType)],
      )
      .get();
  return rows.map((r) => r.data['record_id'] as String).toList();
}

Future<List<String>> deletedRecords(AppDatabase db, String entityType) async {
  final rows = await db
      .customSelect(
        'SELECT record_id FROM deletion_log WHERE entity_type = ?',
        variables: [Variable.withString(entityType)],
      )
      .get();
  return rows.map((r) => r.data['record_id'] as String).toList();
}
