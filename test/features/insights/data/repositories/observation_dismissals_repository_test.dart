import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/observation_dismissals_repository.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ObservationDismissalsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ObservationDismissalsRepository();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver-1'),
            name: Value('A'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<InsightObservationDismissalRow> rowFor(String id) => (db.select(
    db.insightObservationDismissals,
  )..where((t) => t.id.equals(id))).getSingle();

  test('dismiss writes the deterministic row; undismiss clears it', () async {
    await repo.dismiss(
      diverId: 'diver-1',
      rule: ObservationRuleId.rmvTrend,
      fingerprint: 'down:1',
    );
    final id = observationDismissalId(
      'diver-1',
      ObservationRuleId.rmvTrend,
      'down:1',
    );
    final row = await rowFor(id);
    expect(row.dismissedAt, isNotNull);
    expect(row.ruleId, 'rmvTrend');
    expect(row.hlc, isNotNull, reason: 'marked pending for sync');

    await repo.undismiss(
      diverId: 'diver-1',
      rule: ObservationRuleId.rmvTrend,
      fingerprint: 'down:1',
    );
    final cleared = await rowFor(id);
    expect(cleared.dismissedAt, isNull);
    expect(cleared.createdAt, row.createdAt);
    expect(
      await db.select(db.insightObservationDismissals).get(),
      hasLength(1),
    );
  });

  test('watchDismissedKeys: own diver, dismissed only, unknown rules '
      'skipped and left in place', () async {
    await repo.dismiss(
      diverId: 'diver-1',
      rule: ObservationRuleId.diveGap,
      fingerprint: 'd9',
    );
    await repo.dismiss(
      diverId: 'diver-1',
      rule: ObservationRuleId.busiestMonth,
      fingerprint: '8',
    );
    await repo.undismiss(
      diverId: 'diver-1',
      rule: ObservationRuleId.busiestMonth,
      fingerprint: '8',
    );
    await db
        .into(db.insightObservationDismissals)
        .insert(
          InsightObservationDismissalsCompanion.insert(
            id: 'od_future',
            diverId: 'diver-1',
            ruleId: 'fromANewerBuild',
            fingerprint: 'x',
            dismissedAt: const Value(5),
            createdAt: 5,
            updatedAt: 5,
          ),
        );
    expect(await repo.watchDismissedKeys('diver-1').first, {'diveGap:d9'});
    expect(await repo.watchDismissedKeys('other').first, isEmpty);
    expect((await rowFor('od_future')).ruleId, 'fromANewerBuild');
  });
}
