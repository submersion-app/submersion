import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  Future<void> seed() async {
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife', 'son']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    Future<void> item(String id, String owner, {bool active = true}) => db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            isActive: Value(active),
            lastServiceDate: Value(t),
            serviceIntervalDays: const Value(365),
          ),
        );
    await item('owned', 'owner');
    await item('shared', 'wife');
    await item('other', 'son');
    await item('shared-retired', 'wife', active: false);
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['shared', 'shared-retired'],
      diverIds: ['owner'],
      actingDiverId: 'wife',
    );
  }

  group('visible to the owner diver', () {
    setUp(() async {
      db = await setUpTestDatabase();
      repo = EquipmentRepository();
      await seed();
    });
    tearDown(tearDownTestDatabase);

    Set<String> ids(Iterable<dynamic> items) => {
      for (final i in items) i.id as String,
    };

    test('getActiveEquipment returns owned and shared', () async {
      expect(ids(await repo.getActiveEquipment(diverId: 'owner')), {
        'owned',
        'shared',
      });
    });
    test('getRetiredEquipment returns a shared retired item', () async {
      expect(ids(await repo.getRetiredEquipment(diverId: 'owner')), {
        'shared-retired',
      });
    });
    test(
      'getAllEquipment returns owned and shared, never another diver',
      () async {
        expect(ids(await repo.getAllEquipment(diverId: 'owner')), {
          'owned',
          'shared',
          'shared-retired',
        });
      },
    );
    test('getEquipmentByStatus returns shared items', () async {
      expect(
        ids(
          await repo.getEquipmentByStatus(
            EquipmentStatus.active,
            diverId: 'owner',
          ),
        ),
        containsAll(['owned', 'shared']),
      );
    });
    test('getEquipmentWithServiceDates returns shared items', () async {
      expect(ids(await repo.getEquipmentWithServiceDates(diverId: 'owner')), {
        'owned',
        'shared',
      });
    });
    test(
      'searchEquipment finds a shared item and hydrates its owner',
      () async {
        final found = await repo.searchEquipment('shared', diverId: 'owner');
        expect(ids(found), {'shared', 'shared-retired'});
        expect(found.first.diverId, 'wife');
        expect(found.first.createdAt, isNotNull);
      },
    );
    test('a null diver stays unfiltered', () async {
      expect(ids(await repo.getAllEquipment()), hasLength(4));
    });
    test('the sharee side: the son sees only his own', () async {
      expect(ids(await repo.getAllEquipment(diverId: 'son')), {'other'});
    });
    test('visibleIdsAmong and isVisibleTo', () async {
      expect(
        await repo.visibleIdsAmong(['owned', 'shared', 'other'], 'owner'),
        {'owned', 'shared'},
      );
      expect(await repo.isVisibleTo('other', 'owner'), isFalse);
      expect(await repo.isVisibleTo('shared', 'owner'), isTrue);
    });
  });

  test(
    'getActiveEquipment statement count does not grow with shares',
    () async {
      DatabaseService.instance.setTestDatabase(
        AppDatabase(NativeDatabase.memory(logStatements: true)),
      );
      db = DatabaseService.instance.database;
      repo = EquipmentRepository();
      addTearDown(tearDownTestDatabase);
      final logged = <String>[];
      Future<int> count() async {
        logged.clear();
        await runZoned(
          () => repo.getActiveEquipment(diverId: 'owner'),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => logged.add(line),
          ),
        );
        return logged.where((l) => l.startsWith('Drift: Sent')).length;
      }

      await runZoned(
        seed,
        zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
      );
      final few = await count();
      final t = DateTime.now().millisecondsSinceEpoch;
      await runZoned(() async {
        for (var i = 0; i < 20; i++) {
          await db
              .into(db.equipment)
              .insert(
                EquipmentCompanion.insert(
                  id: 'x$i',
                  name: 'x$i',
                  type: 'bcd',
                  createdAt: t,
                  updatedAt: t,
                  diverId: const Value('wife'),
                ),
              );
        }
        await EquipmentShareRepository().shareMany(
          equipmentIds: [for (var i = 0; i < 20; i++) 'x$i'],
          diverIds: ['owner'],
          actingDiverId: 'wife',
        );
      }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));
      expect(await count(), few);
    },
  );
}
