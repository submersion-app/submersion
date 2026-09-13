import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/site_type_seed.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SiteTypeRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteTypeRepository();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000), "
      "('diver-2', 'Other Diver', 1000, 1000)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  SiteTypeEntity custom(String name, {String diverId = 'diver-1'}) =>
      SiteTypeEntity.create(
        id: SiteTypeEntity.generateSlug(name),
        name: name,
        diverId: diverId,
      );

  test(
    "lists built-ins in seed order, then the diver's custom types",
    () async {
      await repository.createSiteType(custom('Mine'));
      await repository.createSiteType(custom('Fjord', diverId: 'diver-2'));

      final types = await repository.getAllSiteTypes(diverId: 'diver-1');

      expect(
        types.take(kBuiltInSiteTypes.length).map((t) => t.id).toList(),
        kBuiltInSiteTypes.map((t) => t.id).toList(),
      );
      expect(types.last.name, 'Mine');
      expect(types.any((t) => t.name == 'Fjord'), isFalse);
    },
  );

  test('without a diver only the built-ins are listed', () async {
    await repository.createSiteType(custom('Mine'));
    final types = await repository.getAllSiteTypes();
    expect(types, hasLength(kBuiltInSiteTypes.length));
    expect(types.every((t) => t.isBuiltIn), isTrue);
  });

  test(
    'a custom type colliding with a built-in slug gets a unique id',
    () async {
      final created = await repository.createSiteType(custom('Wreck'));
      expect(created.id, isNot('wreck'));
      expect(created.id, startsWith('wreck_'));
      expect(created.isBuiltIn, isFalse);
    },
  );

  test('a custom type needs a diver', () async {
    await expectLater(
      repository.createSiteType(
        SiteTypeEntity.create(id: 'mine', name: 'Mine'),
      ),
      throwsException,
    );
  });

  test('built-ins refuse update and delete', () async {
    final wreck = (await repository.getSiteTypeById('wreck'))!;
    await expectLater(
      repository.updateSiteType(wreck.copyWith(name: 'Shipwreck')),
      throwsException,
    );
    await expectLater(repository.deleteSiteType('wreck'), throwsException);
  });

  test('renames a custom type', () async {
    final mine = await repository.createSiteType(custom('Mine'));
    await repository.updateSiteType(mine.copyWith(name: 'Flooded mine'));
    expect((await repository.getSiteTypeById(mine.id))!.name, 'Flooded mine');
  });

  test(
    'deleting a custom type removes and tombstones its site links',
    () async {
      final db = DatabaseService.instance.database;
      final mine = await repository.createSiteType(custom('Mine'));
      await db.customStatement(
        "INSERT INTO dive_sites (id, name, created_at, updated_at) "
        "VALUES ('s1', 'Site', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
        "VALUES ('j1', 's1', '${mine.id}', 0)",
      );

      await repository.deleteSiteType(mine.id);

      expect(await repository.getSiteTypeById(mine.id), isNull);
      expect(await db.select(db.siteSiteTypes).get(), isEmpty);
      final tombstones = await db
          .customSelect(
            "SELECT record_id FROM deletion_log "
            "WHERE entity_type = 'siteSiteTypes'",
          )
          .get();
      expect(tombstones.map((r) => r.read<String>('record_id')), ['j1']);
    },
  );

  test('matches a custom type by case-insensitive name', () async {
    await repository.createSiteType(custom('Mine'));
    final found = await repository.getCustomSiteTypeByName(
      ' mine ',
      diverId: 'diver-1',
    );
    expect(found?.name, 'Mine');
    expect(
      await repository.getCustomSiteTypeByName('mine', diverId: 'diver-2'),
      isNull,
    );
  });

  test('statistics count sites per type', () async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'A', 0, 0), ('s2', 'B', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('a', 's1', 'lake', 0), ('b', 's2', 'lake', 0), "
      "('c', 's2', 'wreck', 0)",
    );

    final stats = await repository.getSiteTypeStatistics(diverId: 'diver-1');
    final byId = {for (final s in stats) s.siteType.id: s.siteCount};
    expect(byId['lake'], 2);
    expect(byId['wreck'], 1);
    expect(byId['reef'], 0);
  });

  test('creating a custom type marks it pending for sync', () async {
    final mine = await repository.createSiteType(custom('Mine'));
    final pending = await DatabaseService.instance.database
        .customSelect(
          "SELECT record_id FROM sync_records WHERE entity_type = 'siteTypes'",
        )
        .get();
    expect(pending.map((r) => r.read<String>('record_id')), [mine.id]);
  });
}
