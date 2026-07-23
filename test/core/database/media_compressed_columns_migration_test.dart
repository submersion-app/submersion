import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('media has the compressed rendition columns after open', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>{
        'compressed_level',
        'compressed_size_bytes',
        'remote_compressed_uploaded_at',
      }),
    );
  });

  test('v134 is present in the migration ladder', () {
    // Relaxed from the exact-latest tripwire when v135 (color accents) landed
    // on top; migration_v135_accent_columns_test.dart now owns the exact
    // assertion. (Renumbered from v130 as main advanced past it at merge time.)
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(134));
    expect(AppDatabase.migrationVersions, contains(134));
  });
}
