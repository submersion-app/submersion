import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test(
    'fresh database has maintenance_processed with a composite PK',
    () async {
      final db = DatabaseService.instance.database;

      // Force schema creation.
      await db.customSelect('SELECT 1').get();

      final cols = await db
          .customSelect("PRAGMA table_info('maintenance_processed')")
          .get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>{'task_name', 'entity_id', 'attempted_at'}),
      );

      // Composite primary key: task_name + entity_id.
      final pkCols = cols
          .where((r) => r.read<int>('pk') > 0)
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(pkCols, {'task_name', 'entity_id'});
    },
  );

  test('currentSchemaVersion is 103', () {
    expect(AppDatabase.currentSchemaVersion, 103);
  });
}
