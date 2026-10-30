import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../helpers/test_database.dart';

/// A diver's list arrangements sync under their own clock (issue #3748), so
/// a sort on a device holding stale settings never puts back a settings
/// change made on another device, and the settings change never puts back a
/// stale sort.
void main() {
  late AppDatabase db;
  late String rowId;
  final repository = DiverSettingsRepository();

  SyncPayload payloadWith(List<Map<String, dynamic>> rows) => SyncPayload(
    version: 1,
    exportedAt: 0,
    deviceId: 'peer',
    checksum: '',
    data: SyncData(diverSettings: rows),
    deletions: const {},
  );

  Future<void> apply(Map<String, dynamic> row) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
  ).debugApplyPayload(payloadWith([row]));

  Future<Map<String, dynamic>> local() async =>
      (await SyncDataSerializer().fetchRecord('diverSettings', rowId))!;

  Future<Map<String, Object?>> read() async =>
      (await db
              .customSelect(
                'SELECT depth_unit, dive_list_sort, site_list_sort, '
                'site_list_view_mode, dive_list_view_mode, '
                'list_arrangement_hlc FROM diver_settings WHERE id = ?',
                variables: [Variable.withString(rowId)],
              )
              .getSingle())
          .data;

  Future<void> saveSort(String diveSort) async {
    final current = (await repository.getSettingsForDiver('d1'))!;
    await repository.updateSettingsForDiver(
      'd1',
      current.copyWith(
        listArrangements: current.listArrangements.copyWith(diveSort: diveSort),
      ),
      previous: current,
    );
  }

  Future<String> laterClock() async {
    await SyncRepository().ensureSyncClockConfigured();
    return SyncClock.instance.issue()!;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Test Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await repository.createSettingsForDiver('d1');
    rowId = (await db.select(db.diverSettings).getSingle()).id;
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  group('registry', () {
    test('diver settings declare one listArrangement group', () {
      expect(SyncFactGroups.of('diverSettings').map((g) => g.name), [
        'listArrangement',
      ]);
      const g = SyncFactGroups.diverSettingsListArrangement;
      expect(g.clockKey, 'listArrangementHlc');
      expect(g.clockColumn, 'list_arrangement_hlc');
      expect(
        g.columns.keys,
        containsAll([
          'diveListSort',
          'equipmentArrangement',
          'equipmentGroupByLocation',
          'diveListViewMode',
          'courseListViewMode',
          'groupTripsInDiveList',
        ]),
      );
      expect(g.columns.keys, isNot(contains('depthUnit')));
    });

    test('every declared column and the clock exist on the table', () {
      final table = db.allTables.firstWhere(
        (t) => t.actualTableName == 'diver_settings',
      );
      final sqlNames = table.$columns.map((c) => c.name).toSet();
      const g = SyncFactGroups.diverSettingsListArrangement;
      expect(sqlNames, contains(g.clockColumn));
      expect(sqlNames, containsAll(g.columns.values));
    });

    test('the JSON keys match the synced row', () async {
      final row = await local();
      const g = SyncFactGroups.diverSettingsListArrangement;
      expect(row.keys, contains(g.clockKey));
      expect(row.keys, containsAll(g.columns.keys));
    });
  });

  test('stale device sort keeps peer settings', () async {
    // The peer's copy before this device sorted.
    final peer = await local();
    await saveSort('maxDepth:ascending');
    // The peer then changed units: a newer ROW clock, but its arrangement
    // is still the one from before this device's sort.
    await apply({...peer, 'depthUnit': 'feet', 'hlc': await laterClock()});

    final row = await read();
    expect(row['depth_unit'], 'feet');
    expect(row['dive_list_sort'], 'maxDepth:ascending');
  });

  test('a sort here never puts back a stale settings value', () async {
    // The peer's copy before this device changed units.
    final peer = await local();
    final current = (await repository.getSettingsForDiver('d1'))!;
    await repository.updateSettingsForDiver(
      'd1',
      current.copyWith(depthUnit: DepthUnit.feet),
      previous: current,
    );
    // The peer then sorted: a newer group clock on a row still holding the
    // old units and the old row clock.
    await apply({
      ...peer,
      'siteListSort': 'name:ascending',
      'listArrangementHlc': await laterClock(),
    });

    final row = await read();
    expect(row['site_list_sort'], 'name:ascending');
    expect(row['depth_unit'], 'feet');
  });

  test('a peer with a newer group clock wins every group column', () async {
    await saveSort('maxDepth:ascending');
    final peer = await local();
    await apply({
      ...peer,
      'diveListSort': 'dateTime:ascending',
      'siteListViewMode': 'table',
      'listArrangementHlc': await laterClock(),
    });

    final row = await read();
    expect(row['dive_list_sort'], 'dateTime:ascending');
    expect(row['site_list_view_mode'], 'table');
  });

  test(
    'an older peer without the group clock key leaves new columns untouched',
    () async {
      await saveSort('maxDepth:ascending');
      final peer = Map<String, dynamic>.of(await local())
        ..remove('listArrangementHlc')
        ..remove('diveListSort');
      await apply({
        ...peer,
        'depthUnit': 'feet',
        'diveListViewMode': 'table',
        'hlc': await laterClock(),
      });

      final row = await read();
      expect(row['depth_unit'], 'feet');
      // Its row clock stands in for the group clock and wins the view mode
      // it carries (the accepted mixed-version limitation), but a column it
      // never knew keeps this device's value.
      expect(row['dive_list_view_mode'], 'table');
      expect(row['dive_list_sort'], 'maxDepth:ascending');
    },
  );

  test('a row first arriving from an older peer takes its row clock as the '
      'group clock', () async {
    // An older build sends no group clock. Left null, the next local
    // settings save here would fill it with a brand-new clock and let this
    // row's untouched view modes beat a newer change made elsewhere.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd2',
            name: 'Second Diver',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final rowClock = await laterClock();
    final peer = Map<String, dynamic>.of(await local())
      ..remove('listArrangementHlc')
      ..remove('diveListSort');
    await apply({...peer, 'id': 'peer-row', 'diverId': 'd2', 'hlc': rowClock});

    final row = await db
        .customSelect(
          "SELECT list_arrangement_hlc FROM diver_settings "
          "WHERE id = 'peer-row'",
        )
        .getSingle();
    expect(row.read<String?>('list_arrangement_hlc'), rowClock);
  });

  group('a never-set arrangement clock', () {
    // A row from before the HLC rollout has neither clock, and the v323
    // backfill has no row clock to copy. Its arrangement was never changed
    // under a clock, so it must lose to any arrangement change a peer made,
    // however late an unrelated settings save here came.
    Future<void> makeClockless() => db.customStatement(
      "UPDATE diver_settings SET hlc = NULL, list_arrangement_hlc = NULL "
      "WHERE diver_id = 'd1'",
    );

    test('stays unset through an unrelated settings save', () async {
      await makeClockless();
      final current = (await repository.getSettingsForDiver('d1'))!;
      await repository.updateSettingsForDiver(
        'd1',
        current.copyWith(depthUnit: DepthUnit.feet),
        previous: current,
      );
      expect((await read())['list_arrangement_hlc'], isNull);
    });

    test('loses to a peer sort made before that save', () async {
      await makeClockless();
      final peerSortClock = await laterClock();
      final peer = await local();
      final current = (await repository.getSettingsForDiver('d1'))!;
      await repository.updateSettingsForDiver(
        'd1',
        current.copyWith(depthUnit: DepthUnit.feet),
        previous: current,
      );
      await apply({
        ...peer,
        'siteListSort': 'name:ascending',
        'listArrangementHlc': peerSortClock,
        'hlc': peerSortClock,
      });

      final row = await read();
      expect(row['site_list_sort'], 'name:ascending');
      expect(row['depth_unit'], 'feet');
    });

    test('a peer row with an explicitly unset clock never wins the group '
        'by its row clock', () async {
      await saveSort('depth:ascending');
      final peer = await local();
      await apply({
        ...peer,
        'diveListSort': null,
        'listArrangementHlc': null,
        'depthUnit': 'feet',
        'hlc': await laterClock(),
      });

      final row = await read();
      expect(row['depth_unit'], 'feet');
      expect(row['dive_list_sort'], 'depth:ascending');
    });
  });

  test(
    'incremental export includes a row whose only change was an arrangement',
    () async {
      final watermark = (await local())['hlc'] as String;
      await saveSort('maxDepth:ascending');
      final payload = await SyncDataSerializer().exportChangeset(
        deviceId: 'me',
        hlcWatermark: watermark,
        deletions: const [],
      );
      expect(payload.data.diverSettings.map((r) => r['id']), [rowId]);
    },
  );
}
