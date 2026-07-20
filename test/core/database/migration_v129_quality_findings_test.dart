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

  test('v129 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v129.
    expect(AppDatabase.currentSchemaVersion, 129);
    expect(AppDatabase.migrationVersions, contains(129));
  });
}
