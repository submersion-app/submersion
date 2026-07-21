import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  test('quality_findings table exists with expected columns', () async {
    final rows = await db
        .customSelect("PRAGMA table_info('quality_findings')")
        .get();
    final cols = [for (final r in rows) r.read<String>('name')];
    expect(
      cols,
      containsAll([
        'id',
        'dive_id',
        'related_dive_id',
        'computer_id',
        'detector_id',
        'detector_version',
        'category',
        'severity',
        'status',
        'params',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('quality_findings indexes exist', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'quality_findings'",
        )
        .get();
    final names = [for (final r in rows) r.read<String>('name')];
    expect(names, contains('idx_quality_findings_dive'));
    expect(names, contains('idx_quality_findings_status'));
  });

  test('v129 quality_findings migration is present', () {
    // The exact-latest tripwire moved to migration_v130 when v130 landed on
    // top of v129; this test now only asserts v129 still has its migration.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(129));
    expect(AppDatabase.migrationVersions, contains(129));
  });
}
