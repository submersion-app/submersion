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

  test('v134 migration is present', () {
    // Relaxed from an exact-latest tripwire: newer migrations (v135 accents,
    // v136 media_stores sweep, v137 weather code) sit above it now.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(134));
    expect(AppDatabase.migrationVersions, contains(134));
  });
}
