import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The v261 columns (issue #2948) ride the generic diverSettings row, so
/// they reach other devices with no serializer change, and a payload from a
/// peer that predates them still applies.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // A placeholder diver_id need not reference a real diver here.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertRow(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-1',
            createdAt: now,
            updatedAt: now,
            certificationListViewMode: const Value('table'),
            courseListViewMode: const Value('table'),
            profileMetricsFollowViewport: const Value(true),
            pscrRatio: const Value(40.0),
          ),
        );
  }

  Future<DiverSetting> readRow(String id) =>
      (db.select(db.diverSettings)..where((t) => t.id.equals(id))).getSingle();

  test('all four columns export and re-import unchanged', () async {
    await insertRow('ds-261');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-261');
    expect(exported!['certificationListViewMode'], 'table');
    expect(exported['courseListViewMode'], 'table');
    expect(exported['profileMetricsFollowViewport'], true);
    expect(exported['pscrRatio'], 40.0);

    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-261'))).go();
    await serializer.upsertRecord('diverSettings', exported);

    final row = await readRow('ds-261');
    expect(row.certificationListViewMode, 'table');
    expect(row.courseListViewMode, 'table');
    expect(row.profileMetricsFollowViewport, isTrue);
    expect(row.pscrRatio, 40.0);
  });

  test('a pre-v261 payload without the columns still applies', () async {
    await insertRow('ds-260');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-260');
    final legacy = Map<String, dynamic>.from(exported!)
      ..remove('certificationListViewMode')
      ..remove('courseListViewMode')
      ..remove('profileMetricsFollowViewport')
      ..remove('pscrRatio');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-260'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await readRow('ds-260');
    expect(row.certificationListViewMode, 'detailed');
    expect(row.courseListViewMode, 'detailed');
    expect(row.profileMetricsFollowViewport, isNull);
    expect(row.pscrRatio, isNull);
  });
}
