import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DiveTank;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_bulk_delete_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/test_database.dart';

/// The logbook's Delete and its five-second Undo (issue #4014). Undo used to
/// rebuild each dive from its flattened domain object, so whatever that object
/// does not carry was gone for good while the snackbar said it was restored.
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  const diverId = 'diver';
  const diveId = 'dive';
  final raw = Uint8List.fromList([1, 2, 3]);

  Future<void> seedRecordedDive() async {
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final computer in ['ca', 'cb']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(computer),
              name: Value(computer),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
    final repository = DiveRepository();
    await repository.createDive(
      Dive(
        id: diveId,
        diverId: diverId,
        dateTime: DateTime.utc(2026, 1, 1, 10),
        runtime: const Duration(seconds: 60),
        tanks: const [
          DiveTank(
            id: 'tank',
            volume: 12,
            startPressure: 200,
            endPressure: 100,
          ),
        ],
      ),
    );
    for (final (source, computer, primary) in [
      ('sa', 'ca', true),
      ('sb', 'cb', false),
    ]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(source),
              diveId: const Value(diveId),
              computerId: Value(computer),
              isPrimary: Value(primary),
              rawData: Value(raw),
              importedAt: Value(DateTime.utc(2026)),
              createdAt: Value(DateTime.utc(2026)),
            ),
          );
      await ProfileSeriesRepository().insertSeries(
        diveId: diveId,
        computerId: computer,
        sourceId: source,
        isPrimary: primary,
        revisionKind: 'computer_import',
        samples: [
          const ProfileSample(timestamp: 0, depth: 0),
          ProfileSample(timestamp: 30, depth: primary ? 10 : 11),
          const ProfileSample(timestamp: 60, depth: 0),
        ],
      );
    }
    await repository.saveEditedProfile(diveId, const [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 30, depth: 9),
      DiveProfilePoint(timestamp: 60, depth: 0),
    ]);
    await TankPressureSeriesRepository().insertSeries(
      diveId: diveId,
      tankId: 'tank',
      computerId: 'ca',
      sourceId: 'sa',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200),
        TankPressureSample(timestamp: 60, pressure: 100),
      ],
    );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: const Value('switch'),
            diveId: const Value(diveId),
            tankId: const Value('tank'),
            computerId: const Value('ca'),
            timestamp: const Value(30),
            createdAt: Value(now),
          ),
        );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: const Value('event'),
            diveId: const Value(diveId),
            computerId: const Value('ca'),
            timestamp: const Value(30),
            eventType: const Value('bookmark'),
            createdAt: Value(now),
          ),
        );
  }

  Future<int> count(String table, [String where = '1 = 1']) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table WHERE $where')
        .getSingle();
    return row.read<int>('c');
  }

  /// Every row of [table] in a fixed order, less what a restore must change:
  /// the clock that lets it beat the delete's tombstone on a peer.
  Future<List<Map<String, Object?>>> rowsOf(String table, String order) async {
    final rows = await db
        .customSelect('SELECT * FROM $table ORDER BY $order')
        .get();
    return [
      for (final row in rows)
        {
          for (final MapEntry(:key, :value) in row.data.entries)
            if (key != 'updated_at' && key != 'hlc') key: value,
        },
    ];
  }

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(paginatedDiveListProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  Future<void> loaded(ProviderContainer container) async {
    for (var i = 0; i < 200; i++) {
      if (container.read(paginatedDiveListProvider).value != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// A mutation refreshes the trip list without awaiting it; let that load
  /// finish so it does not write to a notifier the container has disposed.
  Future<void> settleTrips(ProviderContainer container) async {
    for (var i = 0; i < 200; i++) {
      if (!container.read(tripListNotifierProvider).isLoading) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Deletes [ids] and taps Undo, as the logbook's snackbar does. Returns
  /// whether the Undo says everything came back.
  Future<bool> deleteAndUndo(List<String> ids) async {
    final container = makeContainer();
    await loaded(container);
    final notifier = container.read(paginatedDiveListProvider.notifier);
    final deleted = await notifier.bulkDeleteDives(ids);
    final complete = await notifier.restoreDives(deleted);
    await settleTrips(container);
    return complete;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.setString(currentDiverIdKey, diverId);
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    await seedRecordedDive();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  test('Undo restores every recorded child row exactly', () async {
    await db.customStatement(
      'INSERT INTO dive_scenarios (id, dive_id, name, branch_seconds, '
      "interventions_json, created_at, updated_at) VALUES ('scenario', "
      "'$diveId', 'Skip the deep stop', 30, '{}', 0, 0)",
    );
    const tables = {
      'dives': 'id',
      'dive_data_sources': 'id',
      'dive_profile_series': 'id',
      'tank_pressure_series': 'id',
      'gas_switches': 'id',
      'dive_profile_events': 'id',
      'dive_tanks': 'id',
      'dive_scenarios': 'id',
    };
    final before = {
      for (final MapEntry(key: table, value: order) in tables.entries)
        table: await rowsOf(table, order),
    };
    expect(before['dive_data_sources'], hasLength(2));
    expect(before['dive_profile_series'], hasLength(3));

    expect(await deleteAndUndo([diveId]), isTrue);

    for (final MapEntry(key: table, value: order) in tables.entries) {
      expect(await rowsOf(table, order), before[table], reason: table);
    }
  });

  test('Undo restores the profile revision lineage', () async {
    final series = ProfileSeriesRepository();
    final before = await series.getRevisionsForDive(diveId);
    expect(before.where((r) => r.parentSeriesId != null), isNotEmpty);

    await deleteAndUndo([diveId]);

    expect(await series.getRevisionsForDive(diveId), before);
  });

  test('Undo restores a stored import file the delete reclaimed', () async {
    await db
        .into(db.importedFiles)
        .insert(
          ImportedFilesCompanion.insert(
            id: 'file',
            bytes: raw,
            byteCount: 3,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db.customStatement(
      "UPDATE dive_data_sources SET imported_file_id = 'file' WHERE id = 'sa'",
    );

    await deleteAndUndo([diveId]);

    expect(await count('imported_files', "id = 'file'"), 1);
    expect(
      await count('dive_data_sources', "imported_file_id = 'file'"),
      1,
      reason: 'the source must still name its stored file',
    );
    expect(await count('deletion_log', "record_id = 'file'"), 0);
  });

  test('Undo relinks what the delete unlinked', () async {
    await db.customStatement(
      'INSERT INTO dive_plans (id, name, linked_dive_id, created_at, '
      "updated_at) VALUES ('plan', 'Plan', '$diveId', 0, 0)",
    );

    await deleteAndUndo([diveId]);

    expect(await count('dive_plans', "linked_dive_id = '$diveId'"), 1);
  });

  test('Undo brings back media the delete removed or unlinked', () async {
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('site', 'Reef', 0, 0)",
    );
    final media = MediaRepository();
    for (final (id, siteId) in [('only', null), ('shared', 'site')]) {
      await media.createMedia(
        MediaItem(
          id: id,
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.platformGallery,
          diveId: diveId,
          siteId: siteId,
          takenAt: DateTime.utc(2026),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
    }

    await deleteAndUndo([diveId]);

    expect(await count('media', "dive_id = '$diveId'"), 2);
    expect(await count('deletion_log', "entity_type = 'media'"), 0);
  });

  test('Undo brings back every selected dive', () async {
    final repository = DiveRepository();
    await repository.createDive(
      Dive(
        id: 'other',
        diverId: diverId,
        dateTime: DateTime.utc(2026, 1, 2, 10),
      ),
    );

    await deleteAndUndo([diveId, 'other']);

    expect(await count('dives'), 2);
    expect(await count('dive_data_sources', "dive_id = '$diveId'"), 2);
  });

  test('Undo clears the tombstones and queues the rows for peers', () async {
    await SyncRepository().clearPendingRecords();

    await deleteAndUndo([diveId]);

    expect(await count('deletion_log'), 0);
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.map((r) => '${r.entityType}:${r.recordId}'),
      containsAll([
        'dives:$diveId',
        'diveDataSources:sa',
        'diveDataSources:sb',
        'gasSwitches:switch',
        'diveProfileEvents:event',
      ]),
    );
  });

  test('Undo restores the documents filed under the dive', () async {
    await DocumentRepository().save(
      Document(
        id: 'doc',
        diverId: diverId,
        owner: const DocumentOwner(DocumentOwnerKind.dive, diveId),
        type: DocumentType.other,
        title: 'Log sheet',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      const [],
    );

    await deleteAndUndo([diveId]);

    expect(await count('documents', "id = 'doc' AND dive_id = '$diveId'"), 1);
  });

  test('a delete the log did not record returns the dive and says it is '
      'incomplete', () async {
    await dropChangeLogTriggers(db);

    expect(await deleteAndUndo([diveId]), isFalse);

    expect(await count('dives', "id = '$diveId'"), 1);
    expect(await count('dive_tanks', "dive_id = '$diveId'"), 1);
  });

  test('a record that could not return makes the Undo incomplete', () async {
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('tag', 'Night', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_tags (id, dive_id, tag_id, created_at) "
      "VALUES ('link', '$diveId', 'tag', 0)",
    );
    final container = makeContainer();
    await loaded(container);
    final notifier = container.read(paginatedDiveListProvider.notifier);
    final deleted = await notifier.bulkDeleteDives([diveId]);
    await db.customStatement("DELETE FROM tags WHERE id = 'tag'");

    expect(await notifier.restoreDives(deleted), isFalse);
    await settleTrips(container);

    expect(await count('dives', "id = '$diveId'"), 1);
    expect(await count('dive_tags'), 0);
  });

  group('documents', () {
    late List<String> rearmed;
    late List<String> rebuilt;

    DiveBulkDeleteService service({ChangeLogRevertService? revert}) =>
        DiveBulkDeleteService(
          dives: DiveRepository(),
          changeLog: ChangeLogRepository(),
          revert: revert ?? ChangeLogRevertService(afterDiveWrites: (_) {}),
          restoreDocuments: (entries) async =>
              rebuilt.addAll(entries.map((e) => e.document.id)),
          rearmDocuments: (documents) async =>
              rearmed.addAll(documents.map((d) => d.id)),
        );

    setUp(() async {
      rearmed = [];
      rebuilt = [];
      await DocumentRepository().save(
        Document(
          id: 'doc',
          diverId: diverId,
          owner: const DocumentOwner(DocumentOwnerKind.dive, diveId),
          type: DocumentType.other,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        const [],
      );
    });

    test('a reverted document only has its reminders re-armed', () async {
      final bulk = service();

      expect(await bulk.restore(await bulk.delete([diveId])), isTrue);

      expect(rearmed, ['doc']);
      expect(rebuilt, isEmpty);
    });

    test('with no log entry the document is rebuilt', () async {
      await dropChangeLogTriggers(db);
      final bulk = service();

      await bulk.restore(await bulk.delete([diveId]));

      expect(rearmed, isEmpty);
      expect(rebuilt, ['doc']);
    });

    test('a revert that fails still returns the dive', () async {
      final bulk = service(revert: _FailingRevert());

      expect(await bulk.restore(await bulk.delete([diveId])), isFalse);

      expect(await count('dives', "id = '$diveId'"), 1);
      expect(rebuilt, ['doc']);
    });
  });

  test('the change log shows the Undo as a revert of the delete', () async {
    await deleteAndUndo([diveId]);

    final operations = await db
        .customSelect(
          'SELECT label, source, reverted_by_id FROM change_log_operations '
          "WHERE label = 'bulk_delete'",
        )
        .get();
    expect(operations, hasLength(1));
    expect(operations.single.data['reverted_by_id'], isNotNull);
    expect(
      await db
          .customSelect(
            'SELECT COUNT(*) AS c FROM change_log_operations WHERE source = ?',
            variables: [Variable.withString('revert')],
          )
          .getSingle()
          .then((row) => row.read<int>('c')),
      1,
    );
  });
}

class _FailingRevert extends ChangeLogRevertService {
  _FailingRevert() : super(afterDiveWrites: (_) {});

  @override
  Future<ChangeLogRevertPlan> planOperation(String operationId) =>
      Future.error(StateError('the log is unreadable'));
}
