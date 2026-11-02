import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../helpers/test_database.dart';

/// Issue #3374: the cylinders the old name-and-size guess counted as twin
/// sets, found over a diver's whole logbook so the Gas page can offer to
/// re-role them.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;
  const now = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id, {String? diverId, int dateTime = now}) =>
      db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diverId: Value(diverId),
              diveDateTime: Value(dateTime),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertTank(
    String id,
    String diveId,
    int order, {
    String role = 'backGas',
    double? volume,
    String? name,
    String? preset,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          tankRole: Value(role),
          volume: Value(volume),
          tankName: Value(name),
          presetName: Value(preset),
          tankOrder: Value(order),
        ),
      );

  test('names, presets and 20 L back gas are candidates', () async {
    await insertDive('d1', dateTime: now + 2);
    await insertTank('t1', 'd1', 0, name: 'D12');
    await insertDive('d2', dateTime: now + 1);
    await insertTank('t2', 'd2', 0, preset: 'twin_12');
    await insertDive('d3', dateTime: now);
    await insertTank('t3', 'd3', 0, volume: 22);

    final found = await repository.getTwinSetCandidates();

    expect(found.tankIds, ['t3', 't2', 't1']);
    expect(found.diveIds, ['d3', 'd2', 'd1']);
  });

  test('a 24 L stage and a twin set are not', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0, role: 'stage', volume: 24);
    await insertTank('t2', 'd1', 1, role: 'twinSet', volume: 24);

    final found = await repository.getTwinSetCandidates();

    expect(found.tankIds, isEmpty);
    expect(found.diveIds, isEmpty);
  });

  test('two candidates on one dive give one dive id', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0, volume: 22);
    await insertTank('t2', 'd1', 1, name: 'Doppel 12');

    final found = await repository.getTwinSetCandidates();

    expect(found.tankIds, ['t1', 't2']);
    expect(found.diveIds, ['d1']);
  });

  test("another diver's dive is left out", () async {
    await insertDiver('me');
    await insertDiver('other');
    await insertDive('mine', diverId: 'me');
    await insertTank('t1', 'mine', 0, volume: 22);
    await insertDive('theirs', diverId: 'other');
    await insertTank('t2', 'theirs', 0, volume: 22);

    final found = await repository.getTwinSetCandidates(diverId: 'me');

    expect(found.tankIds, ['t1']);
    expect(found.diveIds, ['mine']);
  });
}
