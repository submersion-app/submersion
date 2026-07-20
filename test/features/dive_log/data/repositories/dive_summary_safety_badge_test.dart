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
    String rule = 'rapidAscent',
  }) async {
    await db
        .into(db.diveSafetyFindings)
        .insert(
          DiveSafetyFindingsCompanion.insert(
            id: id,
            diveId: diveId,
            ruleId: rule,
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

  test('disabled rules are excluded from the summary count', () async {
    await insertDive('dive-1');
    // Two findings for different rules; disabling one leaves the other counted.
    await insertFinding('f1', 'dive-1', rule: 'rapidAscent');
    await insertFinding('f2', 'dive-1', rule: 'missedDecoStop');

    final all = await repository.getDiveSummaries();
    expect(all.single.safetyFindingCount, 2);

    final filtered = await repository.getDiveSummaries(
      disabledSafetyRules: {'rapidAscent'},
    );
    expect(
      filtered.single.safetyFindingCount,
      1,
      reason: 'the rapidAscent finding is excluded, missedDecoStop remains',
    );

    final allDisabled = await repository.getDiveSummaries(
      disabledSafetyRules: {'rapidAscent', 'missedDecoStop'},
    );
    expect(
      allDisabled.single.safetyFindingCount,
      0,
      reason: 'no badge when every finding belongs to a disabled rule',
    );
  });

  test('search summaries exclude disabled rules from the count', () async {
    await insertDive('dive-1');
    await insertFinding('f1', 'dive-1', rule: 'rapidAscent');

    final results = await repository.searchDiveSummaries(
      'Reef',
      disabledSafetyRules: {'rapidAscent'},
    );
    expect(results.single.safetyFindingCount, 0);
  });
}
