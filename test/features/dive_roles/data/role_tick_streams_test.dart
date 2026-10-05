import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/connections/data/repositories/connections_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../helpers/test_database.dart';

/// A role change can write only a role junction (issue #1221): a non-primary
/// role leaves dives.diver_role and dive_buddies.role untouched, and a sync
/// pull writes only the junction row. Every tick that renders roles must
/// therefore watch both junctions.
void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 3, 28).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', $now, $now, $now)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Ann', $now, $now)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<bool> fires(Stream<void> tick, Future<void> Function() write) async {
    var fired = false;
    final sub = tick.listen((_) => fired = true);
    addTearDown(sub.cancel);
    await write();
    for (var i = 0; i < 150 && !fired; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return fired;
  }

  final ticks = <String, Stream<void> Function()>{
    'watchDiveDetailChanges': () => DiveRepository().watchDiveDetailChanges(),
    'watchDiveListChangesWithBuddyLinks': () =>
        DiveRepository().watchDiveListChangesWithBuddyLinks(),
    'watchDivesChangesWithBuddyLinks': () =>
        DiveRepository().watchDivesChangesWithBuddyLinks(),
    'watchConnectionsChanges': () =>
        ConnectionsRepository().watchConnectionsChanges(),
    'watchInsightsChanges': () => InsightsRepository().watchInsightsChanges(),
  };

  for (final entry in ticks.entries) {
    test('${entry.key} fires on a dive_diver_roles write', () async {
      expect(
        await fires(
          entry.value(),
          () => db
              .into(db.diveDiverRoles)
              .insert(
                DiveDiverRolesCompanion.insert(
                  id: 'r1',
                  diveId: 'd1',
                  roleId: 'diveGuide',
                  createdAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('${entry.key} fires on a dive_buddy_roles write', () async {
      expect(
        await fires(
          entry.value(),
          () => db
              .into(db.diveBuddyRoles)
              .insert(
                DiveBuddyRolesCompanion.insert(
                  id: 'x1',
                  diveId: 'd1',
                  buddyId: 'b1',
                  roleId: 'diveGuide',
                  createdAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });
  }
}
