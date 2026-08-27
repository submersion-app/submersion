import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// media, species and field_presets became first-class HLC entities (v85): they
/// were already calling markRecordPending, so registering them in _hlcTargets is
/// all that's needed for their writes to stamp an HLC.
void main() {
  late SyncRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = SyncRepository();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  test('markRecordPending now stamps hlc on a species row', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO species (id, common_name, category) "
      "VALUES ('s1', 'Fish', 'fish')",
    );

    await repo.markRecordPending(
      entityType: 'species',
      recordId: 's1',
      localUpdatedAt: 1000,
    );

    final row = await db
        .customSelect("SELECT hlc FROM species WHERE id = 's1'")
        .getSingle();
    expect(row.read<String?>('hlc'), isNotNull);
  });
}
