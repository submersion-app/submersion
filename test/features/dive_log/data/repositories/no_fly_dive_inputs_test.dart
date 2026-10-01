import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  late ProfileSeriesRepository seriesRepository;
  final now = DateTime.utc(2026, 7, 17, 12);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    seriesRepository = ProfileSeriesRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertDive(
    String id, {
    DateTime? exitTime,
    DateTime? entryTime,
    int? runtimeSeconds,
    String? diverId,
  }) async {
    final created = now.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(
              (entryTime ?? exitTime ?? now).millisecondsSinceEpoch,
            ),
            entryTime: Value(entryTime?.millisecondsSinceEpoch),
            exitTime: Value(exitTime?.millisecondsSinceEpoch),
            runtime: Value(runtimeSeconds),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
  }

  Future<void> insertProfilePoint(
    String diveId, {
    int? decoType,
    double? ceiling,
  }) async {
    await seriesRepository.insertSeries(
      diveId: diveId,
      samples: [
        ProfileSample(
          timestamp: 60,
          depth: 20.0,
          decoType: decoType,
          ceiling: ceiling,
        ),
      ],
      now: now.millisecondsSinceEpoch,
    );
  }

  test('returns dives ending after the cutoff with deco flags', () async {
    final since = now.subtract(const Duration(hours: 48));

    // Recent dive with explicit exit time, deco profile sample.
    await insertDive(
      'recent-deco',
      exitTime: now.subtract(const Duration(hours: 2)),
    );
    await insertProfilePoint('recent-deco', decoType: 2);

    // Recent dive with end derived from entry + runtime, clean profile.
    await insertDive(
      'recent-clean',
      entryTime: now.subtract(const Duration(hours: 6)),
      runtimeSeconds: 3600,
    );
    await insertProfilePoint('recent-clean', decoType: 0, ceiling: 0);

    // Old dive outside the window.
    await insertDive('old', exitTime: now.subtract(const Duration(hours: 72)));
    await insertProfilePoint('old', decoType: 2);

    final inputs = await repository.getNoFlyDiveInputs(since: since);
    final byEnd = {for (final i in inputs) i.endTime.millisecondsSinceEpoch: i};

    expect(inputs, hasLength(2));
    final decoEnd = now
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    final cleanEnd = now
        .subtract(const Duration(hours: 5))
        .millisecondsSinceEpoch;
    expect(byEnd[decoEnd]!.hadDecoObligation, isTrue);
    expect(byEnd[cleanEnd]!.hadDecoObligation, isFalse);
  });

  test('ceiling > 0 also counts as deco', () async {
    await insertDive(
      'ceiling-dive',
      exitTime: now.subtract(const Duration(hours: 1)),
    );
    await insertProfilePoint('ceiling-dive', ceiling: 3.0);

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
    );
    expect(inputs.single.hadDecoObligation, isTrue);
  });

  test('a safety stop ceiling on a series with deco types is no deco '
      '(#2550)', () async {
    // A series stored before the import fix kept a safety stop's depth as
    // its ceiling. The computer reported deco types and never a deco stop,
    // so the dive had no obligation: the same rule the Deco filter uses.
    await insertDive(
      'safety-stop-dive',
      exitTime: now.subtract(const Duration(hours: 1)),
    );
    await insertProfilePoint('safety-stop-dive', decoType: 1, ceiling: 5.0);

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
    );
    expect(inputs.single.hadDecoObligation, isFalse);
  });

  test('a ceiling-only source keeps its deco when a second computer on the '
      'dive records deco types and no deco stop', () async {
    // Two computers disagree: a FIT import logs only a ceiling (no deco
    // types), a second computer logs NDL throughout. The ceiling-only
    // series still recorded an obligation, and the no-fly window must not
    // shrink because the other computer stayed out of deco.
    await insertDive(
      'two-computers',
      exitTime: now.subtract(const Duration(hours: 1)),
    );
    await insertProfilePoint('two-computers', ceiling: 3.0);
    await seriesRepository.insertSeries(
      diveId: 'two-computers',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 60, depth: 20.0, decoType: 0)],
      now: now.millisecondsSinceEpoch,
    );

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
    );
    expect(inputs.single.hadDecoObligation, isTrue);
  });

  test('a recorded deco stop event counts as deco', () async {
    await insertDive(
      'event-deco',
      exitTime: now.subtract(const Duration(hours: 1)),
    );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'evt-1',
            diveId: 'event-deco',
            timestamp: 600,
            eventType: 'decoStopStart',
            createdAt: now.millisecondsSinceEpoch,
          ),
        );

    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
    );
    expect(inputs.single.hadDecoObligation, isTrue);
  });

  test('dive without profile counts as no-deco', () async {
    await insertDive('bare', exitTime: now.subtract(const Duration(hours: 1)));
    final inputs = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
    );
    expect(inputs.single.hadDecoObligation, isFalse);
  });

  test('passing a diverId scopes the query to that diver', () async {
    // A dive with no diver assigned must not surface when the query is scoped
    // to a specific diver (exercises the diver_id WHERE clause).
    await insertDive(
      'unowned',
      exitTime: now.subtract(const Duration(hours: 1)),
    );

    final scoped = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
      diverId: 'diver-1',
    );
    expect(scoped, isEmpty);

    // Without a diver filter the same dive is returned.
    final unscoped = await repository.getNoFlyDiveInputs(
      since: now.subtract(const Duration(hours: 48)),
    );
    expect(unscoped, hasLength(1));
  });
}
