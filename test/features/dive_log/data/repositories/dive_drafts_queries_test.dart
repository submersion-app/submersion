import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// A draft (issue #637) really happened but has no readings yet: it stays
/// out of totals and numbering, and counts for no-fly as a deco dive and
/// for surface interval. A dive is never both planned and a draft; a row
/// that reaches both counts as dived, so the failure is the safe one.
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  // Wall clock flagged UTC, as dive times are stored.
  final now = DateTime.utc(2026, 7, 17, 12);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertDive(
    String id, {
    required DateTime entryTime,
    DateTime? exitTime,
    int? runtimeSeconds,
    double? maxDepth,
    int? diveNumber,
    bool isPlanned = false,
    bool isDraft = false,
  }) async {
    final created = now.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(entryTime.millisecondsSinceEpoch),
            entryTime: Value(entryTime.millisecondsSinceEpoch),
            exitTime: Value(exitTime?.millisecondsSinceEpoch),
            runtime: Value(runtimeSeconds),
            maxDepth: Value(maxDepth),
            diveNumber: Value(diveNumber),
            isPlanned: Value(isPlanned),
            isDraft: Value(isDraft),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
  }

  Future<void> insertClosedDraft(String id) => insertDive(
    id,
    entryTime: now.subtract(const Duration(hours: 3)),
    exitTime: now.subtract(const Duration(hours: 2)),
    isDraft: true,
  );

  test('a draft is left out of statistics', () async {
    await insertDive(
      'logged',
      entryTime: now.subtract(const Duration(days: 1)),
      runtimeSeconds: 3000,
      maxDepth: 20,
      diveNumber: 1,
    );
    await insertClosedDraft('draft');

    final stats = await repository.getStatistics();

    expect(stats.totalDives, 1);
  });

  test('renumbering skips a draft and leaves it unnumbered', () async {
    await insertDive(
      'first',
      entryTime: now.subtract(const Duration(days: 3)),
      diveNumber: 5,
    );
    await insertDive(
      'draft',
      entryTime: now.subtract(const Duration(days: 2)),
      exitTime: now.subtract(const Duration(days: 2, hours: -1)),
      isDraft: true,
    );
    await insertDive(
      'second',
      entryTime: now.subtract(const Duration(days: 1)),
      diveNumber: 9,
    );

    await repository.renumberAllDives();

    expect((await repository.getDiveById('first'))!.diveNumber, 1);
    expect((await repository.getDiveById('draft'))!.diveNumber, isNull);
    expect((await repository.getDiveById('second'))!.diveNumber, 2);
  });

  test('a closed draft counts for no-fly as a deco dive', () async {
    await insertClosedDraft('draft');

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
      now: now,
    );

    expect(inputs, hasLength(1));
    expect(inputs.single.hadDecoObligation, isTrue);
    expect(inputs.single.endTime, now.subtract(const Duration(hours: 2)));
  });

  test('an open draft ends now', () async {
    await insertDive(
      'open',
      entryTime: now.subtract(const Duration(hours: 1)),
      isDraft: true,
    );

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
      now: now,
    );

    expect(inputs.single.endTime, now);
    expect(inputs.single.hadDecoObligation, isTrue);
  });

  test('a draft is not a fuzzy match candidate for a download', () async {
    await insertDive('logged', entryTime: now, runtimeSeconds: 3000);
    await insertDive('draft', entryTime: now, isDraft: true);
    await insertDive('plan', entryTime: now, isPlanned: true);

    final at = now.millisecondsSinceEpoch;
    const window = 3600 * 1000;
    final rows = await db
        .customSelect(
          diveMatchCandidatesSql(scopedToDiver: false),
          variables: [
            Variable<int>(at),
            Variable<int>(at - window),
            Variable<int>(at + window),
          ],
        )
        .get();

    expect(rows.map((r) => r.read<String>('id')), ['logged']);
  });

  test('a draft counts for surface interval', () async {
    await insertDive(
      'draft',
      entryTime: DateTime.utc(2026, 7, 17, 10),
      exitTime: DateTime.utc(2026, 7, 17, 10, 50),
      isDraft: true,
    );
    await insertDive(
      'next',
      entryTime: DateTime.utc(2026, 7, 17, 12),
      runtimeSeconds: 3000,
    );

    final intervals = await repository.getSurfaceIntervals();

    expect(intervals['next'], const Duration(minutes: 70));
  });

  test('saving a dive with both flags keeps the draft', () async {
    final created = await repository.createDive(
      domain.Dive(
        id: '',
        dateTime: DateTime(2026, 7, 17, 10),
        isPlanned: true,
        isDraft: true,
      ),
    );
    var stored = (await repository.getDiveById(created.id))!;
    expect(stored.isPlanned, isFalse);
    expect(stored.isDraft, isTrue);

    await repository.updateDive(
      stored.copyWith(isPlanned: true, isDraft: true),
    );
    stored = (await repository.getDiveById(created.id))!;
    expect(stored.isPlanned, isFalse);
    expect(stored.isDraft, isTrue);
  });

  test('a row with both flags still counts as dived', () async {
    // Two devices' edits merged by sync can write both flags.
    await insertDive(
      'both',
      entryTime: DateTime.utc(2026, 7, 17, 10),
      exitTime: DateTime.utc(2026, 7, 17, 10, 50),
      isPlanned: true,
      isDraft: true,
    );
    await insertDive(
      'next',
      entryTime: DateTime.utc(2026, 7, 17, 12),
      runtimeSeconds: 3000,
    );

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
      now: now,
    );
    final intervals = await repository.getSurfaceIntervals();

    expect(inputs.where((i) => i.hadDecoObligation), hasLength(1));
    expect(intervals['next'], const Duration(minutes: 70));
  });

  test('diveUnfilledSql selects plans and drafts, not logged dives', () async {
    await insertDive('logged', entryTime: now);
    await insertDive('draft', entryTime: now, isDraft: true);
    await insertDive('plan', entryTime: now, isPlanned: true);

    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${diveUnfilledSql('d')} '
          'ORDER BY d.id',
        )
        .get();

    expect(rows.map((r) => r.read<String>('id')), ['draft', 'plan']);
  });
}
