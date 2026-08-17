import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  test('v153 adds wrecks plus the site_features link columns', () async {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(153));
    expect(AppDatabase.migrationVersions, contains(153));

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
        .into(db.wrecks)
        .insert(
          WrecksCompanion.insert(
            id: 'w-1',
            name: 'Hilma Hooker',
            createdAt: 1,
            updatedAt: 1,
            siteId: const Value('site-1'),
            latitude: const Value(12.15),
            longitude: const Value(-68.3),
            vesselType: const Value('ship'),
            depthToDeckMeters: const Value(18),
            depthToSeabedMeters: const Value(30),
          ),
        );

    final row = await (db.select(
      db.wrecks,
    )..where((t) => t.id.equals('w-1'))).getSingle();
    expect(row.siteId, 'site-1');
    expect(row.vesselType, 'ship');
    expect(row.isShared, isFalse);
    expect(row.hlc, isNull);
    expect(row.condition, isNull);

    // A wreck outlives the site: deleting the site NULLs the link.
    await (db.delete(db.diveSites)..where((t) => t.id.equals('site-1'))).go();
    final after = await (db.select(
      db.wrecks,
    )..where((t) => t.id.equals('w-1'))).getSingle();
    expect(after.siteId, isNull);
  });

  test('site_features carries the wreck link and a source default', () async {
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
        .into(db.wrecks)
        .insert(
          WrecksCompanion.insert(
            id: 'w-1',
            name: 'Hilma Hooker',
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
            wreckId: const Value('w-1'),
          ),
        );

    var feature = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals('f-1'))).getSingle();
    expect(feature.wreckId, 'w-1');
    // Untouched rows are diver-placed; 3b sets other values.
    expect(feature.source, 'diver');

    // Deleting the wreck leaves the marker, unlinked.
    await (db.delete(db.wrecks)..where((t) => t.id.equals('w-1'))).go();
    feature = await (db.select(
      db.siteFeatures,
    )..where((t) => t.id.equals('f-1'))).getSingle();
    expect(feature.wreckId, isNull);
  });
}
