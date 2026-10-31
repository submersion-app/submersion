import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// `buddies.excluded_from_rankings` (v330, issue #3624) travels as part of the
/// row's Drift JSON. A peer on an older build sends rows without the key, and
/// the column is not nullable, so both sides of that are pinned here: the
/// floor stays where it is only because these hold.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Map<String, dynamic> peerRow({
    String name = 'Unknown',
    bool excluded = false,
  }) => Buddy(
    id: 'b1',
    name: name,
    notes: '',
    isFavorite: false,
    excludedFromRankings: excluded,
    createdAt: 1,
    updatedAt: 1,
  ).toJson();

  Future<Buddy> stored() =>
      (db.select(db.buddies)..where((t) => t.id.equals('b1'))).getSingle();

  test('a same-version peer carries the flag', () async {
    await serializer.upsertRecord('buddies', peerRow(excluded: true));

    expect((await stored()).excludedFromRankings, isTrue);
  });

  test('a buddy new to this device from an older peer starts ranked', () async {
    final json = peerRow()..remove('excludedFromRankings');

    await serializer.upsertRecord('buddies', json);

    expect((await stored()).excludedFromRankings, isFalse);
  });

  test('an older peer\'s edit keeps the flag set here', () async {
    await db
        .into(db.buddies)
        .insert(
          const BuddiesCompanion(
            id: Value('b1'),
            name: Value('Unknown'),
            excludedFromRankings: Value(true),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
    final json = peerRow(name: 'Renamed')..remove('excludedFromRankings');

    await serializer.upsertRecord('buddies', json);

    final row = await stored();
    expect(row.name, 'Renamed');
    expect(row.excludedFromRankings, isTrue);
  });
}
