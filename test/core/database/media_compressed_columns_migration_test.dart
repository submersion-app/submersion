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

  test('v134 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v134.
    // (Renumbered from v130 as main advanced past it at merge time.)
    expect(AppDatabase.currentSchemaVersion, 134);
    expect(AppDatabase.migrationVersions, contains(134));
  });
}
