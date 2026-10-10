import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A site linked through [DiveRepository.setSite] (the site suggestion banner
/// and the Match Sites review) snaps the same values the dive form's site
/// picker does: water type, entry/exit methods and dive types (issue #3196).
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    String? waterType,
    String? entryMethod,
    String? exitMethod,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            waterType: Value(waterType),
            entryMethod: Value(entryMethod),
            exitMethod: Value(exitMethod),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSite(
    String id, {
    String? waterType,
    String? entryMethod,
    String? exitMethod,
    List<String> siteTypeIds = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            waterType: Value(waterType),
            entryMethod: Value(entryMethod),
            exitMethod: Value(exitMethod),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final typeId in siteTypeIds) {
      await db
          .into(db.siteSiteTypes)
          .insert(
            SiteSiteTypesCompanion(
              id: Value('$id-$typeId'),
              siteId: Value(id),
              siteTypeId: Value(typeId),
              createdAt: Value(now),
            ),
          );
    }
  }

  group('water type', () {
    test('takes the site water type', () async {
      await insertDive('d1');
      await insertSite('s1', waterType: 'salt');

      await repo.setSite('d1', 's1');

      expect((await repo.getDiveById('d1'))!.waterType, WaterType.salt);
    });

    test('replaces the dive value with the new site value', () async {
      await insertDive('d1', waterType: 'fresh');
      await insertSite('s1', waterType: 'brackish');

      await repo.setSite('d1', 's1');

      expect((await repo.getDiveById('d1'))!.waterType, WaterType.brackish);
    });

    test('keeps the dive value when the site has none', () async {
      await insertDive('d1', waterType: 'fresh');
      await insertSite('s1');

      await repo.setSite('d1', 's1');

      expect((await repo.getDiveById('d1'))!.waterType, WaterType.fresh);
    });

    test('never rewrites a stored value it does not recognise', () async {
      await insertDive('d1', waterType: 'lake');
      await insertSite('s1');

      await repo.setSite('d1', 's1');

      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('d1'))).getSingle();
      expect(row.waterType, 'lake');
      expect(row.siteId, 's1');
    });

    test('keeps the dive value when the site is cleared', () async {
      await insertDive('d1', waterType: 'fresh');
      await insertSite('s1', waterType: 'salt');
      await repo.setSite('d1', 's1');

      await repo.setSite('d1', null);

      final dive = (await repo.getDiveById('d1'))!;
      expect(dive.site, isNull);
      expect(dive.waterType, WaterType.salt);
    });
  });

  group('entry and exit methods', () {
    test('a linked exit follows the site entry method', () async {
      await insertDive('d1');
      await insertSite('s1', entryMethod: 'shore');

      await repo.setSite('d1', 's1');

      final dive = (await repo.getDiveById('d1'))!;
      expect(dive.entryMethod, EntryMethod.shore);
      expect(dive.exitMethod, EntryMethod.shore);
    });

    test('an explicit site exit method applies', () async {
      await insertDive('d1');
      await insertSite('s1', entryMethod: 'boat', exitMethod: 'shore');

      await repo.setSite('d1', 's1');

      final dive = (await repo.getDiveById('d1'))!;
      expect(dive.entryMethod, EntryMethod.boat);
      expect(dive.exitMethod, EntryMethod.shore);
    });

    test('a manual exit override survives', () async {
      await insertDive('d1', entryMethod: 'boat', exitMethod: 'shore');
      await insertSite('s1', entryMethod: 'giantStride', exitMethod: 'boat');

      await repo.setSite('d1', 's1');

      final dive = (await repo.getDiveById('d1'))!;
      expect(dive.entryMethod, EntryMethod.giantStride);
      expect(dive.exitMethod, EntryMethod.shore);
    });
  });

  group('dive types', () {
    test('adds the dive types the site types stand for', () async {
      await insertDive('d1');
      await insertSite('s1', siteTypeIds: ['wreck']);

      await repo.setSite('d1', 's1');

      final dive = (await repo.getDiveById('d1'))!;
      expect(dive.diveTypeIds, containsAll(['recreational', 'wreck']));
    });

    test('leaves the dive types alone for a site without types', () async {
      await insertDive('d1');
      await insertSite('s1', waterType: 'salt');

      await repo.setSite('d1', 's1');

      expect((await repo.getDiveById('d1'))!.diveTypeIds, ['recreational']);
    });
  });
}
