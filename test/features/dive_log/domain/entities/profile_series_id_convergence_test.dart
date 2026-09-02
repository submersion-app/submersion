import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';

import '../../../../helpers/test_database.dart';

/// The migrated series id is derived from the packed group's identity so two
/// devices that migrate the same synced legacy rows converge on one row
/// rather than unioning two.
///
/// Two of those members, source and is_primary, are mutable on the SERIES
/// row afterwards, which raises the question of whether a device that packs
/// later can mint a different id for the same logical series. It cannot:
/// the id is computed from the LEGACY row values, and every later mutation
/// writes the series row, never the legacy rows the other device still
/// holds. These pin that, because the answer is not obvious from the call
/// site and the alternative derivations all trade this hazard for a worse
/// one.
void main() {
  late AppDatabase db;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final id in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('demoting a packed series does not change its id', () async {
    // Device A packs, publishes, and the user then makes another computer
    // primary. A peer below the floor never applied the series row, so when
    // it upgrades it packs its own legacy rows, which still say primary.
    final series = ProfileSeriesRepository();
    final migratedId = profileSeriesMigratedId(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: null,
      isPrimary: true,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      isPrimary: true,
      id: migratedId,
      samples: const [ProfileSample(timestamp: 0, depth: 5.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 6.0)],
      now: now,
    );

    await DiveComputerRepository().setPrimaryProfile('dive-1', 'comp-2');

    final rows = await series.getRowsForDives(['dive-1']);
    final demoted = rows.firstWhere((r) => r.computerId == 'comp-1');
    expect(demoted.isPrimary, isFalse);
    expect(
      demoted.id,
      migratedId,
      reason:
          'the peer packing the same legacy rows later mints exactly this id, '
          'so the two rows converge on upsert instead of unioning',
    );
  });

  test('the id follows the legacy row values, not the series row', () {
    // Restating the invariant the test above depends on: the same legacy
    // inputs give the same id on every device, whatever either device has
    // since done to its own series row.
    String idFor({required bool isPrimary, String? sourceId}) =>
        profileSeriesMigratedId(
          diveId: 'dive-1',
          computerId: 'comp-1',
          sourceId: sourceId,
          isPrimary: isPrimary,
        );

    expect(idFor(isPrimary: true), idFor(isPrimary: true));
    // And the members really are part of the key: a group that differs in
    // one is a different series, which is why they cannot be dropped from
    // the derivation to make it "more stable".
    expect(idFor(isPrimary: true), isNot(idFor(isPrimary: false)));
    expect(
      idFor(isPrimary: true),
      isNot(idFor(isPrimary: true, sourceId: 's')),
    );
  });
}
