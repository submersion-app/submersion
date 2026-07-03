import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id, {DateTime? date}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(
              (date ?? DateTime(2026, 6, 1)).millisecondsSinceEpoch,
            ),
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

  test(
    'unfiltered getStatistics counts all dives (unchanged behavior)',
    () async {
      await dive('a');
      await dive('b');
      final stats = await repo.getStatistics();
      expect(stats.totalDives, 2);
    },
  );

  test('tag filter scopes total dives', () async {
    await dive('a');
    await dive('b');
    await tag('dry');
    await link('a', 'dry');
    final stats = await repo.getStatistics(
      filter: const DiveFilterState(tagIds: ['dry']),
    );
    expect(stats.totalDives, 1);
  });
}
