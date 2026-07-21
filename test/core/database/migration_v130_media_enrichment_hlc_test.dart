import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() => db.close());

  test('media_enrichment has an hlc column', () async {
    final rows = await db
        .customSelect("PRAGMA table_info('media_enrichment')")
        .get();
    final cols = [for (final r in rows) r.read<String>('name')];
    expect(
      cols,
      containsAll([
        'id',
        'media_id',
        'dive_id',
        'depth_meters',
        'temperature_celsius',
        'elapsed_seconds',
        'match_confidence',
        'timestamp_offset_seconds',
        'created_at',
        'hlc',
      ]),
    );
  });

  test('v130 media_enrichment migration is present', () {
    // Membership only: v131 landed on top, so the exact-latest tripwire now
    // lives in migration_v131_service_reconcile_test.dart.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(130));
    expect(AppDatabase.migrationVersions, contains(130));
  });
}
