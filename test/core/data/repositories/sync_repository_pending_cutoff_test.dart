import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// Pending marks are an export source for clockless children (they travel
/// on their own, not through a parent's HLC), so clearing them after a
/// publish must spare any mark made after the publish read its snapshot:
/// that edit is not in what was sent, and wiping its mark would drop it.
void main() {
  late SyncRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SyncRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed(String id, String status, int updatedAt) =>
      DatabaseService.instance.database.customStatement(
        'INSERT INTO sync_records (id, entity_type, record_id, '
        'local_updated_at, sync_status, created_at, updated_at) '
        "VALUES (?, 'diveTanks', ?, ?, ?, ?, ?)",
        [id, id, updatedAt, status, updatedAt, updatedAt],
      );

  Future<List<String>> remaining() async {
    final db = DatabaseService.instance.database;
    final rows = await db.select(db.syncRecords).get();
    return rows.map((r) => r.id).toList()..sort();
  }

  test('clearing pending marks spares those made after the snapshot', () async {
    await seed('before', 'pending', 1000);
    await seed('after', 'pending', 3000);
    await seed('conflict', 'conflict', 1000);

    await repository.clearPendingRecords(markedBefore: 2000);

    expect(await remaining(), ['after', 'conflict']);
  });

  test('clearing all records spares those made after the snapshot', () async {
    await seed('before', 'pending', 1000);
    await seed('old-conflict', 'conflict', 1000);
    await seed('after', 'pending', 3000);

    await repository.clearAllSyncRecords(markedBefore: 2000);

    expect(await remaining(), ['after']);
  });

  test('without a cutoff every pending mark is cleared, as before', () async {
    await seed('a', 'pending', 1000);
    await seed('b', 'pending', 3000);

    await repository.clearPendingRecords();

    expect(await remaining(), isEmpty);
  });
}
