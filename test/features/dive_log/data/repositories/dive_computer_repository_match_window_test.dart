import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Which logged dives a download can match. The filter was rewritten as a
/// range so it can seek an index (issue #3863), and these pin that the window
/// itself did not move.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repository;

  final download = DateTime.utc(2026, 6, 1, 9);
  const tolerance = Duration(minutes: 5);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'bill',
            name: 'bill',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    required DateTime date,
    DateTime? entry,
    String? diver,
    bool planned = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diver),
          diveDateTime: Value(date.millisecondsSinceEpoch),
          entryTime: Value(entry?.millisecondsSinceEpoch),
          isPlanned: Value(planned),
          createdAt: const Value(1),
          updatedAt: const Value(1),
        ),
      );

  Future<String?> match({String? diverId}) async =>
      (await repository.findMatchingDiveWithScore(
        profileStartTime: download,
        diverId: diverId,
      ))?.diveId;

  group('findMatchingDiveWithScore window', () {
    test('includes a dive exactly at the tolerance, on either side', () async {
      await insertDive('before', date: download.subtract(tolerance));
      expect(await match(), 'before');
      await db.delete(db.dives).go();

      await insertDive('after', date: download.add(tolerance));
      expect(await match(), 'after');
    });

    test('excludes a dive one millisecond past the tolerance', () async {
      const past = Duration(milliseconds: 1);
      await insertDive('early', date: download.subtract(tolerance + past));
      await insertDive('late', date: download.add(tolerance + past));
      expect(await match(), isNull);
    });

    test('reads the entry time before the dive date', () async {
      await insertDive(
        'entry-near',
        date: download.subtract(const Duration(days: 30)),
        entry: download,
      );
      await insertDive(
        'entry-far',
        date: download,
        entry: download.subtract(const Duration(days: 30)),
      );
      expect(await match(), 'entry-near');
    });

    test('never matches a planned dive', () async {
      await insertDive('plan', date: download, planned: true);
      expect(await match(), isNull);
    });

    test('a diver scope excludes other dives, no scope searches all', () async {
      await insertDive('unassigned', date: download);
      expect(await match(diverId: 'bill'), isNull);
      expect(await match(), 'unassigned');
      // Blank means no scope, not a diver with an empty id.
      expect(await match(diverId: ' '), 'unassigned');

      await insertDive('bills', date: download, diver: 'bill');
      expect(await match(diverId: 'bill'), 'bills');
    });
  });
}
