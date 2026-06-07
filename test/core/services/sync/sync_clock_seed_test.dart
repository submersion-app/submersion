import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';

import '../../../helpers/test_database.dart';

/// M2: after a crash between syncs, the persisted clock (only written at sync
/// time) can lag the HLCs already stamped on rows. ensureSyncClockConfigured
/// must seed from the highest on-disk row HLC, not just the stale persisted
/// value, so the next local write is never ordered behind existing data.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    SyncClock.instance.reset();
    DatabaseService.instance.resetForTesting();
  });

  test(
    'seeds from the highest row HLC when the persisted clock is stale',
    () async {
      final db = DatabaseService.instance.database;
      final repo = SyncRepository();
      await repo.getDeviceId(); // create metadata row

      // Persisted clock is stale (physical 1000)...
      await db.customStatement(
        "UPDATE sync_metadata SET hlc = '000000000001000:000000:me' "
        "WHERE id = 'global'",
      );
      // ...but a dive row already carries a much higher HLC (physical 9000),
      // as if written after the last persisted sync, before a crash.
      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, is_planned, is_favorite, "
        "dive_mode, cns_start, created_at, updated_at, hlc) "
        "VALUES ('d1', 0, 0, 0, 'oc', 0, 0, 0, "
        "'000000000009000:000000:me')",
      );

      SyncClock.instance.reset();
      await repo.ensureSyncClockConfigured();

      expect(
        SyncClock.instance.current!.physicalTime,
        9000,
        reason:
            'clock must seed from the highest on-disk HLC, not the stale '
            'persisted value (1000)',
      );
    },
  );

  test(
    'forces this device node id even when the max row HLC is foreign',
    () async {
      final db = DatabaseService.instance.database;
      final repo = SyncRepository();
      final deviceId = await repo.getDeviceId();

      await db.customStatement(
        "INSERT INTO dives (id, dive_date_time, is_planned, is_favorite, "
        "dive_mode, cns_start, created_at, updated_at, hlc) "
        "VALUES ('d1', 0, 0, 0, 'oc', 0, 0, 0, "
        "'000000000009000:000000:some-other-device')",
      );

      SyncClock.instance.reset();
      await repo.ensureSyncClockConfigured();

      expect(SyncClock.instance.current!.physicalTime, 9000);
      expect(
        SyncClock.instance.current!.nodeId,
        deviceId,
        reason:
            'the seeded clock must issue under our own node id, not the '
            'foreign one from the max row',
      );
    },
  );
}
