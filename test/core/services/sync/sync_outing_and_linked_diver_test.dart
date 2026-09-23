import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';

/// Sync exports rows through the generated toJson and imports them through
/// fromJson, so a new column rides along without serializer changes. This
/// pins that both new columns survive the round trip.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('the generated toJson/fromJson carry both new columns', () async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'chris',
            name: 'Chris',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'b1',
            name: 'Chris',
            linkedDiverId: const Value('chris'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final buddyRow = await (db.select(
      db.buddies,
    )..where((t) => t.id.equals('b1'))).getSingle();
    expect(Buddy.fromJson(buddyRow.toJson()).linkedDiverId, 'chris');

    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: now,
            outingId: const Value('outing-1'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final diveRow = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(Dive.fromJson(diveRow.toJson()).outingId, 'outing-1');
  });
}
