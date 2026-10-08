import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The v262 columns (issue #2948) ride the generic diverSettings row, so
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
    await insertRow('ds-262');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-262');
    expect(exported!['certificationListViewMode'], 'table');
    expect(exported['courseListViewMode'], 'table');
    expect(exported['profileMetricsFollowViewport'], true);
    expect(exported['pscrRatio'], 40.0);

    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-262'))).go();
    await serializer.upsertRecord('diverSettings', exported);

    final row = await readRow('ds-262');
    expect(row.certificationListViewMode, 'table');
    expect(row.courseListViewMode, 'table');
    expect(row.profileMetricsFollowViewport, isTrue);
    expect(row.pscrRatio, 40.0);
  });

  for (final batch in [false, true]) {
    test('an incoming null never clears a local pSCR ratio or viewport '
        'choice (${batch ? 'batch' : 'single'})', () async {
      // Null means "never held a value" (v262), so a peer that has none
      // carries no choice; this device's value stays.
      await insertRow('ds-null');
      final exported = await serializer.fetchRecord('diverSettings', 'ds-null');
      final peer = Map<String, dynamic>.from(exported!)
        ..['pscrRatio'] = null
        ..['profileMetricsFollowViewport'] = null
        ..['gfHigh'] = 70;

      if (batch) {
        await serializer.upsertRecords('diverSettings', [peer]);
      } else {
        await serializer.upsertRecord('diverSettings', peer);
      }

      final row = await readRow('ds-null');
      expect(row.gfHigh, 70);
      expect(row.pscrRatio, 40.0);
      expect(row.profileMetricsFollowViewport, isTrue);
    });
  }

  test('a pre-v262 payload without the columns still applies', () async {
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
