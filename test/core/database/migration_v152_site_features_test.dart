import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  test('v152 is claimed and site_features round-trips', () async {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(152));
    expect(AppDatabase.migrationVersions, contains(152));

    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f-1',
            siteId: 'site-1',
            type: 'wreck',
            latitude: 12.15,
            longitude: -68.3,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final row = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals('f-1'))).getSingle();
    expect(row.type, 'wreck');
    expect(row.bearingDeg, isNull);
    expect(row.hlc, isNull);

    // FK cascade: deleting the site removes the feature.
    await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();
    final left = await db.select(db.siteFeatures).get();
    expect(left, isEmpty);
  });
}
