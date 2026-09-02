import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';

import '../../../../helpers/test_database.dart';

/// Merge and consolidate read their sources decoded, and the repository
/// answers a blob it cannot decode with null rather than an error. Both then
/// delete the source dives, so a blob this build cannot read (bit-rot, or a
/// series written by a newer codec version that synced back to this device)
/// would be dropped on the way through and then deleted.
///
/// Refusing is the only safe answer: the samples cannot be re-based onto the
/// merged timeline without decoding them, and the dives are the last copy.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> createDive(String id, DateTime entry) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        dateTime: entry,
        maxDepth: 10,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 600, depth: 10),
          domain.DiveProfilePoint(timestamp: 1200, depth: 0),
        ],
      ),
    );
  }

  /// Corrupts the stored blob of [diveId]'s series in place, the way storage
  /// bit-rot would: the row and its summary scalars still look sound.
  Future<void> corruptSeriesBlob(String diveId) async {
    final row = (await ProfileSeriesRepository().getRowsForDives([
      diveId,
    ])).single;
    final broken = Uint8List.fromList(row.samples)..[3] ^= 0xFF;
    await db.customStatement(
      'UPDATE dive_profile_series SET samples = ? WHERE id = ?',
      [broken, row.id],
    );
  }

  Future<int> diveCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM dives')
        .getSingle();
    return row.read<int>('n');
  }

  test('merge refuses a dive whose series cannot be decoded', () async {
    await createDive('a', DateTime.utc(2026, 7, 1, 9));
    await createDive('b', DateTime.utc(2026, 7, 1, 10));
    await corruptSeriesBlob('b');

    await expectLater(
      DiveMergeService(diveRepo).apply(['a', 'b']),
      throwsA(isA<UnreadableSeriesException>()),
    );

    expect(await diveCount(), 2, reason: 'neither source may be deleted');
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM dive_profile_series')
              .getSingle())
          .read<int>('n'),
      2,
    );
  });

  test(
    'consolidate refuses a secondary whose series cannot be decoded',
    () async {
      await createDive('a', DateTime.utc(2026, 7, 1, 9));
      await createDive('b', DateTime.utc(2026, 7, 1, 10));
      await corruptSeriesBlob('b');

      await expectLater(
        DiveConsolidationService(
          diveRepo,
        ).apply(targetDiveId: 'a', secondaryDiveIds: const ['b']),
        throwsA(isA<UnreadableSeriesException>()),
      );

      expect(await diveCount(), 2);
    },
  );

  test('a readable pair still merges', () async {
    await createDive('a', DateTime.utc(2026, 7, 1, 9));
    await createDive('b', DateTime.utc(2026, 7, 1, 10));

    final outcome = await DiveMergeService(diveRepo).apply(['a', 'b']);

    expect(outcome.mergedDive.id, isNotEmpty);
    expect(await diveCount(), 1);
  });
}
