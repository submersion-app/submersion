import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The sync FK repair clears or deletes rows with raw SQL, which Drift does
/// not see. A reference with no ON DELETE action of its own (dives.site_id)
/// is left dangling by a remote parent deletion that Drift has no
/// propagation rule for, so unless the repair announces its own writes, every
/// watcher of the repaired table keeps showing the stale reference (#2851).
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('site', 'Reef', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, site_id, dive_date_time, created_at, "
      "updated_at) VALUES ('d', 'site', 1700000000000, 1, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  test('clearing a dangling reference tells that table\'s watchers', () async {
    await pumpEventQueue();
    var diveNotifications = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.dives))
        .listen((_) => diveNotifications++);
    addTearDown(sub.cancel);

    await serializer.applyInDeferredFkTransaction(() async {
      await serializer.deleteRecord('diveSites', 'site');
      await serializer.repairDanglingForeignKeys();
    });
    await pumpEventQueue();

    final row = await db
        .customSelect("SELECT site_id FROM dives WHERE id = 'd'")
        .getSingle();
    expect(row.read<String?>('site_id'), isNull);
    expect(diveNotifications, greaterThan(0));
  });

  test('deleting an orphan tells that table\'s watchers', () async {
    // Plan children reference their plan with no ON DELETE action, so a
    // remote plan deletion orphans them and only the repair removes them.
    await db.customStatement(
      "INSERT INTO dive_plans (id, name, gf_low, gf_high, created_at, "
      "updated_at) VALUES ('plan', 'Plan', 30, 70, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_plan_tanks (id, plan_id, created_at, updated_at) "
      "VALUES ('tank', 'plan', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_plan_segments (id, plan_id, type, start_depth, "
      "end_depth, duration_seconds, tank_id, gas_o2, gas_he, created_at, "
      "updated_at) VALUES ('seg', 'plan', 'bottom', 30, 30, 600, 'tank', "
      "21, 0, 1, 1)",
    );
    await pumpEventQueue();
    final notified = <String>{};
    final sub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([db.divePlanTanks, db.divePlanSegments]),
        )
        .listen((updates) => notified.addAll(updates.map((u) => u.table)));
    addTearDown(sub.cancel);

    await serializer.applyInDeferredFkTransaction(() async {
      await serializer.deleteRecord('divePlans', 'plan');
      await serializer.repairDanglingForeignKeys();
    });
    await pumpEventQueue();

    final left = await db
        .customSelect(
          'SELECT (SELECT COUNT(*) FROM dive_plan_tanks) + '
          '(SELECT COUNT(*) FROM dive_plan_segments) AS n',
        )
        .getSingle();
    expect(left.read<int>('n'), 0);
    expect(notified, containsAll(['dive_plan_tanks', 'dive_plan_segments']));
  });
}
