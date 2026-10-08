import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Weight names (issue #956) through the sync serializer: a named row
/// round-trips, and a row from a peer that predates the column (no `label`
/// key) neither throws nor wipes a local name.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // The rows reference a dive and a preset this test never creates.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(tearDownTestDatabase);

  Map<String, dynamic> weightRow({String? label}) => {
    'id': 'w1',
    'diveId': 'd1',
    'weightType': 'trimWeights',
    'amountKg': 2.0,
    'notes': '',
    'createdAt': 1,
    'label': ?label,
  };

  Map<String, dynamic> entryRow({String? label}) => {
    'id': 'e1',
    'presetId': 'p1',
    'weightType': 'trimWeights',
    'amountKg': 2.0,
    'notes': '',
    'sortOrder': 0,
    'createdAt': 1,
    'label': ?label,
  };

  for (final (type, id, row) in [
    ('diveWeights', 'w1', weightRow),
    ('weightPresetEntries', 'e1', entryRow),
  ]) {
    test('$type: a named row round-trips', () async {
      await serializer.upsertRecord(type, row(label: 'Top pocket'));
      final stored = await serializer.fetchRecord(type, id);
      expect(stored!['label'], 'Top pocket');
    });

    test('$type: a new row without the key arrives unnamed', () async {
      await serializer.upsertRecord(type, row());
      final stored = await serializer.fetchRecord(type, id);
      expect(stored!['label'], '');
    });

    test('$type: an older peer\'s copy keeps the local name', () async {
      await serializer.upsertRecord(type, row(label: 'Top pocket'));
      await serializer.upsertRecord(type, row()..['amountKg'] = 3.0);
      final stored = await serializer.fetchRecord(type, id);
      expect(stored!['amountKg'], 3.0);
      expect(stored['label'], 'Top pocket');
    });
  }
}
