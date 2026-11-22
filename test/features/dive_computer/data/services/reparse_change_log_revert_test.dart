import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_batch_service.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A re-parse reverted from the change log puts the dive's profile and
/// pressure series back as they were, and takes away the ones it wrote
/// (issue #4848).
void main() {
  late AppDatabase db;
  late ReparseService reparse;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;
  final repository = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    reparse = ReparseService(db: db);
    profileSeries = ProfileSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
    tankSeries = TankPressureSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<void> addComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value('Computer $id'),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> addSource(
    String id, {
    required String? computerId,
    required bool isPrimary,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: const Value('dive'),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          sourceFormat: const Value('dive_computer'),
          rawData: Value(Uint8List.fromList([1, 2, 3])),
          descriptorVendor: const Value('Shearwater'),
          descriptorProduct: const Value('Perdix'),
          descriptorModel: const Value(42),
          importedAt: Value(DateTime.utc(2026, 1, 15, 10)),
          createdAt: Value(DateTime.utc(2026, 1, 15, 10)),
        ),
      );

  /// A downloaded series of [sourceId], deeper than any re-parse writes.
  /// [isEdit] null is a series written before edits were marked.
  Future<String> addSeries(
    String sourceId, {
    required String? computerId,
    required bool isPrimary,
    bool? isEdit = false,
  }) => profileSeries.insertSeries(
    diveId: 'dive',
    computerId: computerId,
    sourceId: sourceId,
    isPrimary: isPrimary,
    isEdit: isEdit,
    samples: const [
      ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 300, depth: 40),
      ProfileSample(timestamp: 600, depth: 0),
    ],
    now: 1000,
  );

  pigeon.ParsedDive parsed({bool withTank = false}) => pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 1,
    dateTimeDay: 15,
    dateTimeHour: 10,
    dateTimeMinute: 0,
    dateTimeSecond: 0,
    maxDepthMeters: 25,
    avgDepthMeters: 14,
    durationSeconds: 3000,
    minTemperatureCelsius: 18,
    samples: [
      pigeon.ProfileSample(
        timeSeconds: 0,
        depthMeters: 0,
        pressureBar: withTank ? 200 : null,
        tankIndex: withTank ? 0 : null,
      ),
      pigeon.ProfileSample(
        timeSeconds: 60,
        depthMeters: 25,
        pressureBar: withTank ? 150 : null,
        tankIndex: withTank ? 0 : null,
      ),
      pigeon.ProfileSample(timeSeconds: 120, depthMeters: 0),
    ],
    tanks: [
      if (withTank)
        pigeon.TankInfo(index: 0, gasMixIndex: 0, volumeLiters: 12.0),
    ],
    gasMixes: [
      if (withTank) pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
    ],
    events: [],
  );

  /// Settles what the setup wrote, so the log holds only the re-parse.
  Future<void> forget() async {
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  }

  const columns = {
    'dive_profile_series':
        'id, computer_id, source_id, is_primary, is_edit, sample_count, '
        'start_timestamp, end_timestamp, max_depth, samples',
    'dive_profile_series_history':
        'series_id, parent_series_id, root_series_id, content_hash, '
        'revision_kind',
    'tank_pressure_series':
        'id, tank_id, computer_id, source_id, sample_count, samples',
  };

  Future<List<Map<String, Object?>>> rows(String table) async => [
    for (final row
        in await db
            .customSelect('SELECT ${columns[table]} FROM $table ORDER BY 1')
            .get())
      row.data,
  ];

  /// The dive's profile series and their lineage.
  Future<List<List<Map<String, Object?>>>> profile() async => [
    await rows('dive_profile_series'),
    await rows('dive_profile_series_history'),
  ];

  Future<String> reparseOperation() async {
    await repository.settleAll();
    final operation = await db
        .customSelect(
          'SELECT id FROM change_log_operations WHERE label = ? '
          'ORDER BY started_at DESC, rowid DESC LIMIT 1',
          variables: [Variable.withString(ChangeLogLabels.reparse)],
        )
        .getSingle();
    return operation.read<String>('id');
  }

  Future<void> revert(String operationId) async {
    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await service.execute(await service.planOperation(operationId));
  }

  test('reverting a bulk re-parse of a two-source dive restores both '
      'computers\' series', () async {
    await addComputer('c1');
    await addComputer('c2');
    await addSource('s1', computerId: 'c1', isPrimary: true);
    await addSource('s2', computerId: 'c2', isPrimary: false);
    await addSeries('s1', computerId: 'c1', isPrimary: true);
    await addSeries('s2', computerId: 'c2', isPrimary: false);
    await forget();
    final before = await profile();

    await ReparseBatchService(
      reparse,
    ).run(['dive'], parseFn: (_, _, _, _) async => parsed());
    expect(await profile(), isNot(before));

    await revert(await reparseOperation());

    expect(await profile(), before);
  });

  test('reverting the revert puts the re-parsed series back', () async {
    await addComputer('c1');
    await addSource('s1', computerId: 'c1', isPrimary: true);
    await addSeries('s1', computerId: 'c1', isPrimary: true);
    await forget();
    final before = await profile();

    await ReparseBatchService(
      reparse,
    ).run(['dive'], parseFn: (_, _, _, _) async => parsed());
    final reparsed = await profile();
    final operationId = await reparseOperation();
    await revert(operationId);
    expect(await profile(), before);

    await repository.settleAll();
    final undo = await db
        .customSelect(
          'SELECT id FROM change_log_operations WHERE revert_of_id = ?',
          variables: [Variable.withString(operationId)],
        )
        .getSingle();
    await revert(undo.read<String>('id'));

    expect(await profile(), reparsed);
  });

  test('reverting an older re-parse after a newer one keeps the newer '
      'series alone', () async {
    await addComputer('c1');
    await addSource('s1', computerId: 'c1', isPrimary: true);
    await addSeries('s1', computerId: 'c1', isPrimary: true);
    await forget();

    final batch = ReparseBatchService(reparse);
    await batch.run(['dive'], parseFn: (_, _, _, _) async => parsed());
    final older = await reparseOperation();
    await batch.run(['dive'], parseFn: (_, _, _, _) async => parsed());
    final newer = await profile();

    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    final plan = await service.planOperation(older);
    expect(
      plan.items.where(
        (i) => i.event.table == 'dive_profile_series' && i.isBlocked,
      ),
      isNotEmpty,
    );
    await service.execute(plan);

    expect(await profile(), newer);
  });

  // A computer delete leaves the recording and an unmarked edit alike, and
  // a re-parse keeps the edit (issue #4529): it is no newer reading of the
  // source, so the recording still comes back.
  test('reverting a re-parse restores the recording beside the unmarked '
      'edit it kept', () async {
    await addSource('s1', computerId: null, isPrimary: true);
    await addSeries('s1', computerId: null, isPrimary: true);
    await addSeries('s1', computerId: null, isPrimary: true, isEdit: null);
    await forget();
    final before = await profile();

    await ReparseBatchService(
      reparse,
    ).run(['dive'], parseFn: (_, _, _, _) async => parsed());
    expect(await profile(), isNot(before));

    await revert(await reparseOperation());

    expect(await profile(), before);
  });

  test(
    'a re-parsed series stays when the one it replaced cannot return',
    () async {
      await addComputer('c1');
      await addSource('s1', computerId: 'c1', isPrimary: true);
      await addSeries('s1', computerId: 'c1', isPrimary: true);
      await forget();

      await ReparseBatchService(
        reparse,
      ).run(['dive'], parseFn: (_, _, _, _) async => parsed());
      final operationId = await reparseOperation();
      // The old series needs its computer back to return.
      await db.customStatement("DELETE FROM dive_computers WHERE id = 'c1'");
      final reparsed = await rows('dive_profile_series');
      expect(reparsed, hasLength(1));

      await revert(operationId);

      expect(await rows('dive_profile_series'), reparsed);
    },
  );

  // A later removal re-zeroed the re-parsed series, so a revert of only
  // what did not change since keeps it, and its old series with it: both
  // would be two strands of one computer.
  test('a revert that skips changes since keeps the old series out while '
      'its replacement stays', () async {
    await addComputer('c1');
    await addSource('s1', computerId: 'c1', isPrimary: true);
    final recording = await addSeries('s1', computerId: 'c1', isPrimary: true);
    // An edit the re-parse keeps, whose lineage names the recording: the
    // re-parse clears that link, and putting it back needs the recording.
    await profileSeries.insertSeries(
      diveId: 'dive',
      sourceId: 's1',
      isPrimary: false,
      isEdit: true,
      parentSeriesId: recording,
      revisionKind: 'edit',
      samples: const [ProfileSample(timestamp: 0, depth: 3)],
      now: 1000,
    );
    await forget();

    await ReparseBatchService(
      reparse,
    ).run(['dive'], parseFn: (_, _, _, _) async => parsed());
    final operationId = await reparseOperation();
    await ChangeLogScope.bulk(
      db,
      label: ChangeLogLabels.removeSource,
      body: () => db.customStatement(
        'UPDATE dive_profile_series SET start_timestamp = start_timestamp + 60',
      ),
    );
    await repository.settleAll();
    final shifted = await profile();

    final service = ChangeLogRevertService(afterDiveWrites: (_) {});
    final plan = await service.planOperation(operationId);
    await service.execute(plan, includeChangedSince: false);

    expect(await profile(), shifted);
  });

  test(
    'reverting a re-parse restores the pressure series it replaced',
    () async {
      await addComputer('c1');
      await addSource('s1', computerId: 'c1', isPrimary: true);
      await addSeries('s1', computerId: 'c1', isPrimary: true);
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive'),
              computerId: Value('c1'),
              tankOrder: Value(0),
              o2Percent: Value(32.0),
              hePercent: Value(0.0),
              tankRole: Value('backGas'),
            ),
          );
      await tankSeries.insertSeries(
        diveId: 'dive',
        tankId: 'tank-0',
        computerId: 'c1',
        sourceId: 's1',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 230),
          TankPressureSample(timestamp: 600, pressure: 90),
        ],
        now: 1000,
      );
      await forget();
      final profilesBefore = await profile();
      final pressuresBefore = await rows('tank_pressure_series');

      await ReparseBatchService(
        reparse,
      ).run(['dive'], parseFn: (_, _, _, _) async => parsed(withTank: true));
      expect(await rows('tank_pressure_series'), isNot(pressuresBefore));

      await revert(await reparseOperation());

      expect(await profile(), profilesBefore);
      expect(await rows('tank_pressure_series'), pressuresBefore);
    },
  );

  test('a single dive\'s re-parse is one revertable re-parse entry', () async {
    await addComputer('c1');
    await addSource('s1', computerId: 'c1', isPrimary: true);
    await addSeries('s1', computerId: 'c1', isPrimary: true);
    await forget();
    final before = await profile();

    final result = await reparse.reparseDive(
      'dive',
      parseFn: (_, _, _, _) async => parsed(),
    );
    expect(result.errors, isEmpty);
    expect(await profile(), isNot(before));

    await revert(await reparseOperation());

    expect(await profile(), before);
  });
}
