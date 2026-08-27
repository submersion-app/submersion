import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Sync serializes whole Drift rows with `row.toJson()`
/// (lib/core/services/sync/sync_data_serializer.dart), so a new column rides
/// along without any per-field registration. This is what guarantees that
/// stays true for the site entry/exit method columns.
void main() {
  test('a dive_sites row carries entry/exit method through toJson', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Blue Hole',
            createdAt: 0,
            updatedAt: 0,
            entryMethod: const Value('boat'),
            exitMethod: const Value('ladder'),
          ),
        );

    final row = await (db.select(
      db.diveSites,
    )..where((t) => t.id.equals('site-1'))).getSingle();

    final json = row.toJson();
    expect(json['entryMethod'], 'boat');
    expect(json['exitMethod'], 'ladder');

    final restored = DiveSite.fromJson(json);
    expect(restored.entryMethod, 'boat');
    expect(restored.exitMethod, 'ladder');
  });

  test('an unset entry/exit method round-trips as null', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-2',
            name: 'Shore Spot',
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    final row = await (db.select(
      db.diveSites,
    )..where((t) => t.id.equals('site-2'))).getSingle();

    final restored = DiveSite.fromJson(row.toJson());
    expect(restored.entryMethod, isNull);
    expect(restored.exitMethod, isNull);
  });
}
