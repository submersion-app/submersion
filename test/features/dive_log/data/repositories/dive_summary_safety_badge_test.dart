import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  final now = DateTime.utc(2026, 7, 16).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> insertDive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            name: Value('Reef dive $id'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertFinding(
    String id,
    String diveId, {
    bool dismissed = false,
  }) async {
    await db
        .into(db.diveSafetyFindings)
        .insert(
          DiveSafetyFindingsCompanion.insert(
            id: id,
            diveId: diveId,
            ruleId: 'rapidAscent',
            severity: 'caution',
            engineVersion: 1,
            dismissedAt: Value(dismissed ? now : null),
            createdAt: now,
          ),
        );
  }

  test('summaries carry non-dismissed safety finding counts', () async {
    await insertDive('dive-1');
    await insertDive('dive-2');
    await insertFinding('f1', 'dive-1');
    await insertFinding('f2', 'dive-1', dismissed: true);

    final summaries = await repository.getDiveSummaries();
    final byId = {for (final s in summaries) s.id: s};

    expect(byId['dive-1']!.safetyFindingCount, 1);
    expect(byId['dive-2']!.safetyFindingCount, 0);
  });

  test('search summaries carry safety finding counts too', () async {
    await insertDive('dive-1');
    await insertFinding('f1', 'dive-1');

    final results = await repository.searchDiveSummaries('Reef');
    expect(results, isNotEmpty);
    expect(results.first.safetyFindingCount, 1);
  });
}
