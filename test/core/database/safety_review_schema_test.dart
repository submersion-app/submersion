import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('safety review tables exist with expected columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final reviewCols = await db
        .customSelect("PRAGMA table_info('dive_safety_reviews')")
        .get();
    final reviewNames = reviewCols.map((r) => r.read<String>('name')).toSet();
    expect(
      reviewNames,
      containsAll(['dive_id', 'engine_version', 'reviewed_at']),
    );

    final findingCols = await db
        .customSelect("PRAGMA table_info('dive_safety_findings')")
        .get();
    final findingNames = findingCols.map((r) => r.read<String>('name')).toSet();
    expect(
      findingNames,
      containsAll([
        'id',
        'dive_id',
        'rule_id',
        'severity',
        'start_timestamp',
        'end_timestamp',
        'value',
        'engine_version',
        'dismissed_at',
        'created_at',
      ]),
    );

    final settingsCols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final settingsNames = settingsCols
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(
      settingsNames,
      containsAll(['safety_review_enabled', 'safety_review_disabled_rules']),
    );
  });
}
