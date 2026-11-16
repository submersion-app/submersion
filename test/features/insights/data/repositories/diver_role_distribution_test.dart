import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/insights_dive_filters.dart';

import '../../../../helpers/test_database.dart';

/// The My role card (#4409): dives per role the diver held, counted once
/// under each role a dive holds, plus Not set. Every bar's count must equal
/// the dives its drill-in opens.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;
  final now = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await db
        .into(db.diveRoles)
        .insert(
          DiveRolesCompanion.insert(
            id: 'their-role',
            diverId: const Value('other'),
            name: 'Their Role',
            createdAt: now,
            updatedAt: now,
          ),
        );
    Future<void> dive(
      String id,
      String? role, {
      List<String> junction = const [],
      int runtime = 600,
    }) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diverId: const Value('me'),
              diveDateTime: now,
              diverRole: Value(role),
              runtime: Value(runtime),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final (i, roleId) in junction.indexed) {
        await db
            .into(db.diveDiverRoles)
            .insert(
              DiveDiverRolesCompanion.insert(
                id: '$id-$i',
                diveId: id,
                roleId: roleId,
                createdAt: now,
              ),
            );
      }
    }

    await dive(
      'a',
      'instructor',
      junction: ['instructor', 'safetyDiver'],
      runtime: 1200,
    );
    await dive('b', 'instructor');
    await dive('c', 'safetyDiver');
    await dive('d', null);
    // Older versions changed the scalar after the junction was written.
    await dive('e', 'buddy', junction: ['instructor', 'buddy']);
    await dive('f', 'solo', junction: ['solo', 'buddy']);
    // Another diver's custom role is not borrowed (resolveDiveRole).
    await dive('g', 'their-role');
  });
  tearDown(tearDownTestDatabase);

  Map<String, int> counts(List<DistributionSegment> segments) => {
    for (final s in segments) s.label: s.count,
  };

  test('each role a dive holds counts once, with Not set', () async {
    final segments = await repository.getDiverRoleDistribution(diverId: 'me');
    expect(counts(segments), {
      'instructor': 2,
      'safetyDiver': 2,
      'buddy': 1,
      'solo': 1,
      kNotRecordedDistributionKey: 1,
    });
    expect(segments.last.label, kNotRecordedDistributionKey);
    final instructor = segments.firstWhere((s) => s.label == 'instructor');
    expect(instructor.totalDurationSeconds, 1800);
  });

  test('every bar opens exactly the dives it counts', () async {
    final segments = await repository.getDiverRoleDistribution(diverId: 'me');
    for (final s in segments) {
      final ids = await repository.getCountedDiveIds(
        diverId: 'me',
        filter: diverRoleDivesFilter(const DiveFilterState(), s.label),
      );
      expect(ids, hasLength(s.count), reason: s.label);
    }
  });

  test('the Insights filter scopes the bars', () async {
    final segments = await repository.getDiverRoleDistribution(
      diverId: 'me',
      filter: const DiveFilterState(diverRoleIds: ['instructor']),
    );
    expect(counts(segments), {'instructor': 2, 'safetyDiver': 1});
  });

  test('a bar opened under a role scope keeps that role', () async {
    final ids = await repository.getCountedDiveIds(
      diverId: 'me',
      filter: diverRoleDivesFilter(
        const DiveFilterState(diverRoleIds: ['instructor']),
        'safetyDiver',
      ),
    );
    expect(ids, ['a']);
  });

  test('no dives gives no segments', () async {
    await db.customStatement('DELETE FROM dives');
    expect(await repository.getDiverRoleDistribution(diverId: 'me'), isEmpty);
  });
}
