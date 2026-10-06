import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Sync replication for custom certification agencies and levels (issue
/// #690). Unlike dive_roles these tables hold no built-ins: every row is user
/// data and syncs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncDataSerializer serializer;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('a', 'A', 0, 0)",
    );
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  String hlcAt(int physical) =>
      '${physical.toString().padLeft(15, '0')}:000000:dev-a';

  Map<String, dynamic> agencyRow(String id, {int at = 1000}) => {
    'id': id,
    'diverId': 'a',
    'name': 'Club $id',
    'colorArgb': 0xFF3B82F6,
    'isShared': true,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': hlcAt(at),
  };

  Map<String, dynamic> levelRow(
    String id, {
    String agencyId = 'ag1',
    int order = 0,
  }) => {
    'id': id,
    'diverId': 'a',
    'agencyId': agencyId,
    'name': 'Level $id',
    'isProgression': true,
    'sortOrder': order,
    'isShared': false,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': hlcAt(1000),
  };

  test('export includes custom agencies and levels', () async {
    await serializer.upsertRecord(
      'customCertificationAgencies',
      agencyRow('ag1'),
    );
    await serializer.upsertRecord('customCertificationLevels', levelRow('l1'));
    final payload = await serializer.exportData(
      deviceId: 'dev-a',
      deletions: const [],
    );
    expect(payload.data.customCertificationAgencies.map((r) => r['id']), [
      'ag1',
    ]);
    expect(payload.data.customCertificationLevels.map((r) => r['id']), ['l1']);
  });

  test('incremental export: only rows with hlc > watermark', () async {
    await serializer.upsertRecord(
      'customCertificationAgencies',
      agencyRow('old', at: 1000),
    );
    await serializer.upsertRecord(
      'customCertificationAgencies',
      agencyRow('new', at: 9000),
    );
    final changeset = await serializer.exportChangeset(
      deviceId: 'dev-a',
      hlcWatermark: hlcAt(5000),
      deletions: const [],
    );
    final ids = changeset.data.customCertificationAgencies
        .map((r) => r['id'])
        .toSet();
    expect(ids, contains('new'));
    expect(ids, isNot(contains('old')));
  });

  test('agencies round-trip through single and batch paths', () async {
    await serializer.upsertRecord(
      'customCertificationAgencies',
      agencyRow('ag1'),
    );
    final row = await serializer.fetchRecord(
      'customCertificationAgencies',
      'ag1',
    );
    expect(row!['name'], 'Club ag1');
    expect(row['isShared'], isTrue);
    await serializer.upsertRecords('customCertificationAgencies', [
      agencyRow('ag2'),
    ]);
    expect(
      await serializer.recordIdsFor('customCertificationAgencies'),
      containsAll(['ag1', 'ag2']),
    );
    await serializer.deleteRecord('customCertificationAgencies', 'ag1');
    expect(
      await serializer.fetchRecord('customCertificationAgencies', 'ag1'),
      isNull,
    );
  });

  test(
    'a level applies before its agency arrives, and sort order survives',
    () async {
      await serializer.upsertRecords('customCertificationLevels', [
        levelRow('l1', order: 1),
        levelRow('l2', order: 0),
      ]);
      final rows = await serializer.fetchRecords('customCertificationLevels', [
        'l1',
        'l2',
      ]);
      expect(rows['l1']!['sortOrder'], 1);
      expect(rows['l2']!['sortOrder'], 0);
      expect(
        await serializer.recordIdsFor('customCertificationLevels'),
        containsAll(['l1', 'l2']),
      );
    },
  );

  test('SyncData JSON carries both lists', () {
    final data = SyncData.fromJson({
      'customCertificationAgencies': [agencyRow('ag1')],
      'customCertificationLevels': [levelRow('l1')],
    });
    expect(data.customCertificationAgencies.single['id'], 'ag1');
    expect(data.customCertificationLevels.single['id'], 'l1');
    final json = data.toJson();
    expect(json['customCertificationAgencies'], hasLength(1));
    expect(json['customCertificationLevels'], hasLength(1));
  });

  test(
    'deleteAllRecords clears every custom row (no built-ins to keep)',
    () async {
      await serializer.upsertRecord(
        'customCertificationAgencies',
        agencyRow('ag1'),
      );
      await serializer.deleteAllRecords('customCertificationAgencies');
      final db = DatabaseService.instance.database;
      final rows = await db
          .customSelect('SELECT id FROM custom_certification_agencies')
          .get();
      expect(rows, isEmpty);
    },
  );

  test('both are clocked entities', () {
    expect(
      SyncService.entityHasUpdatedAt['customCertificationAgencies'],
      isTrue,
    );
    expect(SyncService.entityHasUpdatedAt['customCertificationLevels'], isTrue);
  });
}
