import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

Map<String, dynamic> _diver(String id, String name, {int updatedAt = 1}) => {
  'id': id,
  'name': name,
  'medicalNotes': '',
  'notes': '',
  'isDefault': false,
  'createdAt': 1,
  'updatedAt': updatedAt,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test(
    'upsertRecords writes all records and conflict-updates in place',
    () async {
      final s = SyncDataSerializer();
      await s.upsertRecords('divers', [_diver('a', 'A'), _diver('b', 'B')]);
      expect((await s.fetchRecord('divers', 'a'))?['name'], 'A');
      expect((await s.fetchRecord('divers', 'b'))?['name'], 'B');

      // Re-upsert 'a' with a new name updates in place (insertOnConflictUpdate).
      await s.upsertRecords('divers', [_diver('a', 'A2', updatedAt: 2)]);
      expect((await s.fetchRecord('divers', 'a'))?['name'], 'A2');
    },
  );

  test('upsertRecords is a no-op for an empty list', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('divers', const []);
    expect(await s.fetchRecord('divers', 'a'), isNull);
  });

  test(
    'fetchRecords returns id-keyed rows matching per-id fetchRecord',
    () async {
      final s = SyncDataSerializer();
      await s.upsertRecords('divers', [_diver('a', 'A'), _diver('b', 'B')]);
      final got = await s.fetchRecords('divers', ['a', 'b', 'missing']);
      expect(got.keys.toSet(), {'a', 'b'}); // absent ids simply absent
      expect(got['a'], await s.fetchRecord('divers', 'a'));
      expect(got['b'], await s.fetchRecord('divers', 'b'));
    },
  );

  test('fetchRecords keys settings by their key column (not id)', () async {
    final s = SyncDataSerializer();
    await s.upsertRecords('settings', [
      {'key': 'theme', 'value': 'dark', 'updatedAt': 1},
      {'key': 'units', 'value': 'metric', 'updatedAt': 1},
    ]);
    final got = await s.fetchRecords('settings', ['theme', 'units']);
    expect(got.keys.toSet(), {'theme', 'units'});
    expect(got['theme'], await s.fetchRecord('settings', 'theme'));
  });
}
