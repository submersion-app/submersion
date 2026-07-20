import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final now = DateTime.utc(2026, 7, 17, 12);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
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
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value('$diveId-p${decoType ?? 0}-${ceiling ?? 0}'),
            diveId: Value(diveId),
            timestamp: const Value(60),
            depth: const Value(20.0),
            decoType: Value(decoType),
            ceiling: Value(ceiling),
          ),
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
