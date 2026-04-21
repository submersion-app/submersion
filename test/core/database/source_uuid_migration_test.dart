import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh database has source_uuid column on dive_data_sources', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final cols = await db
        .customSelect("PRAGMA table_info('dive_data_sources')")
        .get();
    final names = cols.map((r) => r.data['name'] as String).toSet();
    expect(
      names.contains('source_uuid'),
      isTrue,
      reason: 'dive_data_sources must have source_uuid column',
    );
    await db.close();
  });
}
