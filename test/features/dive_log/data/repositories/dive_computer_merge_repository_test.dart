import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerMergeRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerMergeRepository();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver-1'),
            name: Value('Diver'),
            createdAt: Value(1000),
            updatedAt: Value(1000),
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> insertComputer({
    required String id,
    String name = 'Petrel 3',
    String? diverId = 'diver-1',
    String? manufacturer = 'Shearwater',
    String? model = 'Petrel 3',
    String? serialNumber = '3101949313',
    String? firmwareVersion,
    String? bluetoothAddress,
    int diveCount = 0,
    bool isFavorite = false,
    String notes = '',
    int? lastDownloadTimestamp,
    String? lastDiveFingerprint,
    String? equipmentId,
    int updatedAt = 1000,
  }) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serialNumber),
            firmwareVersion: Value(firmwareVersion),
            bluetoothAddress: Value(bluetoothAddress),
            diveCount: Value(diveCount),
            isFavorite: Value(isFavorite),
            notes: Value(notes),
            lastDownloadTimestamp: Value(lastDownloadTimestamp),
            lastDiveFingerprint: Value(lastDiveFingerprint),
            equipmentId: Value(equipmentId),
            createdAt: const Value(1000),
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(1000),
            computerId: Value(computerId),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );
  }

  Future<void> insertDataSource(
    String id, {
    required String diveId,
    String? computerId,
    bool isPrimary = false,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sourceFormat: const Value('dive_computer'),
            importedAt: Value(DateTime(2026)),
            createdAt: Value(DateTime(2026)),
          ),
        );
  }

  Future<void> insertTank(
    String id, {
    required String diveId,
    String? computerId,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
          ),
        );
  }

  Future<void> insertProfileEvent(
    String id, {
    required String diveId,
    String? computerId,
  }) async {
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            timestamp: const Value(0),
            eventType: const Value('ascent'),
            computerId: Value(computerId),
            createdAt: const Value(1000),
          ),
        );
  }

  Future<void> insertQualityFinding(
    String id, {
    required String diveId,
    String? computerId,
  }) async {
    await db
        .into(db.qualityFindings)
        .insert(
          QualityFindingsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            detectorId: const Value('detector'),
            detectorVersion: const Value(1),
            category: const Value('profile'),
            severity: const Value('info'),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );
  }

  Future<void> insertProfileSeries(
    String id, {
    required String diveId,
    String? computerId,
    bool isPrimary = true,
  }) async {
    await db
        .into(db.diveProfileSeries)
        .insert(
          DiveProfileSeriesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sampleCount: const Value(0),
            startTimestamp: const Value(0),
            endTimestamp: const Value(0),
            maxDepth: const Value(0),
            firstDepth: const Value(0),
            lastDepth: const Value(0),
            codecVersion: const Value(1),
            samples: Value(Uint8List(0)),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );
  }

  Future<void> insertTankSeries(
    String id, {
    required String diveId,
    required String tankId,
    String? computerId,
  }) async {
    await db
        .into(db.tankPressureSeries)
        .insert(
          TankPressureSeriesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            tankId: Value(tankId),
            computerId: Value(computerId),
            sampleCount: const Value(0),
            startTimestamp: const Value(0),
            endTimestamp: const Value(0),
            codecVersion: const Value(1),
            samples: Value(Uint8List(0)),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );
  }

  Future<void> insertEquipment(String id) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            name: Value('Gear $id'),
            type: const Value('computer'),
            createdAt: const Value(1000),
            updatedAt: const Value(1000),
          ),
        );
  }

  Future<void> linkDiveEquipment(String diveId, String equipmentId) async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion(
            diveId: Value(diveId),
            equipmentId: Value(equipmentId),
          ),
        );
  }

  Future<List<String>> computerIdsIn(
    String table, {
    String column = 'computer_id',
  }) async {
    final rows = await db
        .customSelect('SELECT $column AS c FROM $table ORDER BY rowid')
        .get();
    return rows.map((r) => r.read<String?>('c') ?? 'NULL').toList();
  }

  Future<bool> isPending(String entityType, String recordId) async {
    final row =
        await (db.select(db.syncRecords)..where(
              (t) =>
                  t.entityType.equals(entityType) & t.recordId.equals(recordId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<bool> hasTombstone(String entityType, String recordId) async {
    final row =
        await (db.select(db.deletionLog)..where(
              (t) =>
                  t.entityType.equals(entityType) & t.recordId.equals(recordId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<DiveComputer?> computerRow(String id) => (db.select(
    db.diveComputers,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Dive> diveRow(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  // ---------------------------------------------------------------------------
  // Argument validation
  // ---------------------------------------------------------------------------

  group('argument validation', () {
    test('rejects an empty duplicate list', () async {
      await insertComputer(id: 'a');

      expect(
        () =>
            repository.mergeComputers(survivorId: 'a', duplicateIds: const []),
        throwsArgumentError,
      );
    });

    test('rejects a duplicate list that only names the survivor', () async {
      await insertComputer(id: 'a');

      expect(
        () => repository.mergeComputers(survivorId: 'a', duplicateIds: ['a']),
        throwsArgumentError,
      );
    });

    test('throws when the survivor does not exist', () async {
      await insertComputer(id: 'b');

      expect(
        () => repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']),
        throwsStateError,
      );
    });

    test(
      'throws when a duplicate does not exist and changes nothing',
      () async {
        await insertComputer(id: 'a');
        await insertComputer(id: 'b');
        await insertDive('d1', computerId: 'b');

        await expectLater(
          () => repository.mergeComputers(
            survivorId: 'a',
            duplicateIds: ['b', 'missing'],
          ),
          throwsStateError,
        );

        expect((await diveRow('d1')).computerId, 'b');
        expect(await computerRow('b'), isNotNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Repointing
  // ---------------------------------------------------------------------------

  group('mergeComputers', () {
    test('re-pointed events carry a fresh clock', () async {
      // The survivor may already have a scope tombstone on this dive from
      // a split. An event moved into that scope with its old clock would be
      // deleted by any relayed copy of it, and skipped by every peer that
      // holds it (#1926).
      await insertComputer(id: 'a');
      await insertComputer(id: 'b', name: 'ssss');
      await insertDive('d1', computerId: 'b');
      await insertProfileEvent('e1', diveId: 'd1', computerId: 'b');
      await SyncRepository().logScopedDeletion(
        const EventScopeTombstone(diveId: 'd1', computerId: 'a'),
      );
      final scope = (await db.select(db.deletionLog).get()).single;

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

      final event = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.id.equals('e1'))).getSingle();
      expect(event.computerId, 'a');
      expect(
        Hlc.parse(event.hlc!).compareTo(Hlc.parse(scope.originHlc!)),
        greaterThan(0),
      );
    });

    test(
      'moves every reference from the duplicates onto the survivor',
      () async {
        await insertComputer(id: 'a');
        await insertComputer(id: 'b', name: 'ssss');
        await insertComputer(id: 'c', name: 'third');
        await insertDive('d1', computerId: 'b');
        await insertDive('d2', computerId: 'c');
        await insertDive('d3', computerId: 'a');
        await insertDataSource('ds1', diveId: 'd1', computerId: 'b');
        await insertTank('t1', diveId: 'd1', computerId: 'b');
        await insertProfileEvent('e1', diveId: 'd2', computerId: 'c');
        await insertQualityFinding('q1', diveId: 'd1', computerId: 'b');
        await insertProfileSeries('ps1', diveId: 'd1', computerId: 'b');
        await insertProfileSeries('ps2', diveId: 'd3', computerId: 'a');
        await insertTankSeries(
          'ts1',
          diveId: 'd2',
          tankId: 't1',
          computerId: 'c',
        );

        final result = await repository.mergeComputers(
          survivorId: 'a',
          duplicateIds: ['b', 'c'],
        );

        expect(result.survivorId, 'a');
        expect(result.mergedComputerIds, ['b', 'c']);
        expect(result.movedDiveCount, 2);

        expect(await computerIdsIn('dives'), ['a', 'a', 'a']);
        expect(await computerIdsIn('dive_data_sources'), ['a']);
        expect(await computerIdsIn('dive_tanks'), ['a']);
        expect(await computerIdsIn('dive_profile_events'), ['a']);
        expect(await computerIdsIn('quality_findings'), ['a']);
        expect(await computerIdsIn('dive_profile_series'), ['a', 'a']);
        expect(await computerIdsIn('tank_pressure_series'), ['a']);
      },
    );

    test(
      'deletes the duplicates with tombstones and keeps the survivor',
      () async {
        await insertComputer(id: 'a');
        await insertComputer(id: 'b');

        await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

        expect(await computerRow('a'), isNotNull);
        expect(await computerRow('b'), isNull);
        expect(await hasTombstone('diveComputers', 'b'), isTrue);
        expect(await hasTombstone('diveComputers', 'a'), isFalse);
      },
    );

    test('writes the merged fields onto the survivor row', () async {
      await insertComputer(
        id: 'a',
        firmwareVersion: null,
        diveCount: 21,
        lastDownloadTimestamp: 5000,
        lastDiveFingerprint: 'old',
        notes: 'Primary',
      );
      await insertComputer(
        id: 'b',
        name: 'ssss',
        firmwareVersion: '103',
        diveCount: 2,
        isFavorite: true,
        lastDownloadTimestamp: 9000,
        lastDiveFingerprint: 'new',
        notes: 'From the iPhone',
      );

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

      final survivor = (await computerRow('a'))!;
      expect(survivor.name, 'Petrel 3');
      expect(survivor.firmwareVersion, '103');
      expect(survivor.diveCount, 23);
      expect(survivor.isFavorite, isTrue);
      expect(survivor.lastDownloadTimestamp, 9000);
      expect(survivor.lastDiveFingerprint, 'new');
      expect(survivor.notes, 'Primary\n\nFrom the iPhone');
      expect(survivor.updatedAt, greaterThan(1000));
    });

    test(
      'marks the survivor, affected dives and clocked children pending',
      () async {
        await insertComputer(id: 'a');
        await insertComputer(id: 'b');
        await insertDive('d1', computerId: 'b');
        await insertDive('d2', computerId: 'a');
        await insertDataSource('ds2', diveId: 'd2', computerId: 'b');
        await insertQualityFinding('q1', diveId: 'd1', computerId: 'b');
        await insertProfileSeries('ps1', diveId: 'd1', computerId: 'b');
        await insertTank('t', diveId: 'd1');
        await insertTankSeries(
          'ts1',
          diveId: 'd1',
          tankId: 't',
          computerId: 'b',
        );

        await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

        expect(await isPending('diveComputers', 'a'), isTrue);
        expect(await isPending('dives', 'd1'), isTrue);
        // d2 already pointed at the survivor, but its data source moved and
        // that table has no clock of its own: the dive must carry the change.
        expect(await isPending('dives', 'd2'), isTrue);
        expect((await diveRow('d2')).updatedAt, greaterThan(1000));
        expect(await isPending('qualityFindings', 'q1'), isTrue);
        expect(await isPending('diveProfileSeries', 'ps1'), isTrue);
        expect(await isPending('tankPressureSeries', 'ts1'), isTrue);
      },
    );

    test('leaves dives that never referenced a duplicate untouched', () async {
      await insertComputer(id: 'a');
      await insertComputer(id: 'b');
      await insertDive('d1', computerId: 'a');
      await insertDive('d2');

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

      expect((await diveRow('d1')).updatedAt, 1000);
      expect((await diveRow('d2')).updatedAt, 1000);
      expect(await isPending('dives', 'd1'), isFalse);
    });

    test('notifies the sync bus exactly once, after the commit', () async {
      await insertComputer(id: 'a');
      await insertComputer(id: 'b');
      await insertDive('d1', computerId: 'b');
      await insertProfileSeries('ps1', diveId: 'd1', computerId: 'b');
      await insertTank('t', diveId: 'd1');
      await insertTankSeries('ts1', diveId: 'd1', tankId: 't', computerId: 'b');

      var notifications = 0;
      final subscription = SyncEventBus.changes.listen((_) {
        notifications += 1;
      });
      addTearDown(subscription.cancel);

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);
      await Future<void>.delayed(Duration.zero);

      // The series repositories restamp their rows inside the merge
      // transaction; only the merge itself may announce the change.
      expect(notifications, 1);
    });

    test('keeps the survivor bluetooth address when it has one', () async {
      await insertComputer(id: 'a', bluetoothAddress: 'MAC-A');
      await insertComputer(id: 'b', bluetoothAddress: 'MAC-B');

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

      expect((await computerRow('a'))!.bluetoothAddress, 'MAC-A');
    });

    test(
      'adopts a duplicate bluetooth address when the survivor has none',
      () async {
        await insertComputer(id: 'a', bluetoothAddress: null);
        await insertComputer(id: 'b', bluetoothAddress: 'MAC-B');

        await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

        expect((await computerRow('a'))!.bluetoothAddress, 'MAC-B');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Gear twins
  // ---------------------------------------------------------------------------

  group('gear twins', () {
    test(
      'repoints dive gear links from the duplicate twin to the survivor twin',
      () async {
        await insertEquipment('gear-a');
        await insertEquipment('gear-b');
        await insertComputer(id: 'a', equipmentId: 'gear-a');
        await insertComputer(id: 'b', equipmentId: 'gear-b');
        await insertDive('d1', computerId: 'b');
        await insertDive('d2', computerId: 'b');
        await linkDiveEquipment('d1', 'gear-b');
        await linkDiveEquipment('d2', 'gear-b');
        await linkDiveEquipment('d2', 'gear-a');

        await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

        final links = await (db.select(db.diveEquipment)).get();
        final pairs = links.map((l) => '${l.diveId}|${l.equipmentId}').toSet();
        expect(pairs, {'d1|gear-a', 'd2|gear-a'});
        expect(await isPending('diveEquipment', 'd1|gear-a'), isTrue);
        expect(await hasTombstone('diveEquipment', 'd1|gear-b'), isTrue);
        expect(await hasTombstone('diveEquipment', 'd2|gear-b'), isTrue);
        expect((await computerRow('a'))!.equipmentId, 'gear-a');
        // The duplicate's gear item itself is left for the user to manage.
        final gearB = await (db.select(
          db.equipment,
        )..where((t) => t.id.equals('gear-b'))).getSingleOrNull();
        expect(gearB, isNotNull);
      },
    );

    test('adopts the duplicate twin when the survivor has none', () async {
      await insertEquipment('gear-b');
      await insertComputer(id: 'a', equipmentId: null);
      await insertComputer(id: 'b', equipmentId: 'gear-b');
      await insertDive('d1', computerId: 'b');
      await linkDiveEquipment('d1', 'gear-b');

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

      expect((await computerRow('a'))!.equipmentId, 'gear-b');
      final links = await (db.select(db.diveEquipment)).get();
      expect(links.single.equipmentId, 'gear-b');
    });

    test('does nothing when both records share one twin', () async {
      await insertEquipment('gear');
      await insertComputer(id: 'a', equipmentId: 'gear');
      await insertComputer(id: 'b', equipmentId: 'gear');
      await insertDive('d1', computerId: 'b');
      await linkDiveEquipment('d1', 'gear');

      await repository.mergeComputers(survivorId: 'a', duplicateIds: ['b']);

      final links = await (db.select(db.diveEquipment)).get();
      expect(links.single.equipmentId, 'gear');
      expect(await hasTombstone('diveEquipment', 'd1|gear'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Counting
  // ---------------------------------------------------------------------------

  group('countAffectedDives', () {
    test('counts each dive once across every referencing table', () async {
      await insertComputer(id: 'a');
      await insertComputer(id: 'b');
      // A third record so the a-and-b case has a survivor outside the pair.
      await insertComputer(id: 'c');
      await insertDive('d1', computerId: 'b');
      await insertDive('d2', computerId: 'a');
      await insertDive('d3');
      await insertDataSource('ds1', diveId: 'd1', computerId: 'b');
      await insertProfileSeries('ps1', diveId: 'd1', computerId: 'b');
      await insertTank('t', diveId: 'd3');
      await insertTankSeries('ts3', diveId: 'd3', tankId: 't', computerId: 'b');

      expect(
        await repository.countAffectedDives(
          survivorId: 'a',
          duplicateIds: ['b'],
        ),
        2,
      );
      expect(
        await repository.countAffectedDives(
          survivorId: 'c',
          duplicateIds: ['a', 'b'],
        ),
        3,
      );
      expect(
        await repository.countAffectedDives(
          survivorId: 'a',
          duplicateIds: const [],
        ),
        0,
      );
      // The survivor is never one of the duplicates it absorbs.
      expect(
        await repository.countAffectedDives(
          survivorId: 'a',
          duplicateIds: ['a'],
        ),
        0,
      );
    });

    test(
      'counts a dive that references a duplicate through gear only',
      () async {
        await insertEquipment('gear-a');
        await insertEquipment('gear-b');
        await insertComputer(id: 'a', equipmentId: 'gear-a');
        await insertComputer(id: 'b', equipmentId: 'gear-b');
        // d1 carries no computer_id anywhere: the duplicate reaches it solely
        // through the gear twin the merge is about to repoint.
        await insertDive('d1');
        await linkDiveEquipment('d1', 'gear-b');

        final preview = await repository.countAffectedDives(
          survivorId: 'a',
          duplicateIds: ['b'],
        );
        final result = await repository.mergeComputers(
          survivorId: 'a',
          duplicateIds: ['b'],
        );

        expect(preview, 1);
        expect(result.movedDiveCount, preview);
      },
    );

    test('does not count gear links the survivor already holds', () async {
      await insertEquipment('gear');
      await insertComputer(id: 'a', equipmentId: 'gear');
      await insertComputer(id: 'b', equipmentId: 'gear');
      await insertDive('d1');
      await linkDiveEquipment('d1', 'gear');

      // Both records share one twin, the common case when the identity
      // resolver matched them by serial. Nothing moves.
      expect(
        await repository.countAffectedDives(
          survivorId: 'a',
          duplicateIds: ['b'],
        ),
        0,
      );
    });

    test('counts gear links against the twin the survivor adopts', () async {
      await insertEquipment('gear-b');
      await insertEquipment('gear-c');
      await insertComputer(id: 'a', equipmentId: null);
      await insertComputer(id: 'b', equipmentId: 'gear-b');
      await insertComputer(id: 'c', equipmentId: 'gear-c');
      await insertDive('d1');
      await insertDive('d2');
      await linkDiveEquipment('d1', 'gear-b');
      await linkDiveEquipment('d2', 'gear-c');

      // The survivor has no twin, so it adopts gear-b from the first
      // duplicate. Only gear-c's links move.
      final preview = await repository.countAffectedDives(
        survivorId: 'a',
        duplicateIds: ['b', 'c'],
      );
      final result = await repository.mergeComputers(
        survivorId: 'a',
        duplicateIds: ['b', 'c'],
      );

      expect(preview, 1);
      expect(result.movedDiveCount, preview);
    });
  });
}
