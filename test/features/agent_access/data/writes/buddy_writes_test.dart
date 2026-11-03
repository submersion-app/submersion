import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/buddy_writes.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

void main() {
  late AppDatabase db;
  late RecordHarness h;
  late BuddyWrites writes;

  setUp(() async {
    db = await setUpTestDatabase();
    h = RecordHarness(db);
    await seedTwoDivers(db);
    writes = BuddyWrites(RecordRepositories());
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'b1',
            name: 'Anna',
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            diverId: const Value(kDiverA),
            email: const Value('anna@example.com'),
            phone: const Value('+1 555'),
          ),
        );
  });

  tearDown(() => tearDownTestDatabase());

  test('update writes only the named columns', () async {
    await writes.update(
      'b1',
      kDiverA,
      const RecordUpdate(values: {'name': 'Ana'}),
    );

    final doc = (await h.one('buddies', 'b1'))!;
    expect(doc['name'], 'Ana');
    expect(doc['email'], 'anna@example.com');
  });

  test('null clears a nullable column', () async {
    await writes.update(
      'b1',
      kDiverA,
      const RecordUpdate(values: {'email': null}),
    );

    final doc = (await h.one('buddies', 'b1'))!;
    expect(doc['email'], isNull);
    expect(doc['phone'], '+1 555');
  });

  test('every codec key has a column', () async {
    const samples = <String, Object?>{
      'name': 'Ana',
      'email': 'ana@example.com',
      'phone': '+1 777',
      'social_handle': '@ana',
      'notes': 'Rescue diver',
      'is_favorite': true,
      'excluded_from_rankings': true,
    };
    expect(samples.keys.toSet(), writes.fields.keys.toSet());

    await writes.update('b1', kDiverA, const RecordUpdate(values: samples));

    final doc = (await h.one('buddies', 'b1'))!;
    for (final MapEntry(:key, :value) in samples.entries) {
      expect(doc[key], value, reason: key);
    }
  });

  test('create returns an id the record reads back under', () async {
    final id = await writes.create(kDiverB, {'name': 'Rui', 'phone': '+1 999'});

    final doc = (await h.one('buddies', id, diverId: kDiverB))!;
    expect(doc['diver_id'], kDiverB);
    expect(doc['name'], 'Rui');
    expect(doc['phone'], '+1 999');
  });

  test('delete removes the row', () async {
    await writes.delete('b1', kDiverA);

    expect(await h.one('buddies', 'b1'), isNull);
  });
}
