import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id, {String? visibility}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            visibility: Value(visibility),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> tag(String id) async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> link(String diveId, String tagId) async {
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion(
            id: Value('$diveId-$tagId'),
            diveId: Value(diveId),
            tagId: Value(tagId),
            createdAt: Value(now),
          ),
        );
  }

  test('visibility distribution respects a tag filter', () async {
    await dive('a', visibility: 'Good');
    await dive('b', visibility: 'Poor');
    await tag('dry');
    await link('a', 'dry');

    final all = await repo.getVisibilityDistribution();
    expect(all.length, 2);

    final filtered = await repo.getVisibilityDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.length, 1);
    expect(filtered.first.label, 'Good');
  });

  test('dive-type distribution respects a tag filter', () async {
    await dive('a');
    await dive('b');
    await db
        .into(db.diveDiveTypes)
        .insert(
          DiveDiveTypesCompanion(
            id: const Value('t-a'),
            diveId: const Value('a'),
            diveTypeId: const Value('wreck'),
            createdAt: Value(now),
          ),
        );
    await db
        .into(db.diveDiveTypes)
        .insert(
          DiveDiveTypesCompanion(
            id: const Value('t-b'),
            diveId: const Value('b'),
            diveTypeId: const Value('wreck'),
            createdAt: Value(now),
          ),
        );
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getDiveTypeDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(filtered.first.count, 1); // only dive 'a'
  });

  test('gas-mix distribution respects a tag filter', () async {
    await dive('a');
    await dive('b');
    for (final id in ['a', 'b']) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value('tank-$id'),
              diveId: Value(id),
              o2Percent: const Value(32.0),
              hePercent: const Value(0.0),
              tankOrder: const Value(0),
            ),
          );
    }
    await tag('dry');
    await link('a', 'dry');

    final filtered = await repo.getGasMixDistribution(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    final total = filtered.fold<int>(0, (s, seg) => s + seg.count);
    expect(total, 1); // only dive 'a'
  });
}
