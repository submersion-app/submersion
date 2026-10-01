import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Adopt replays the library it joins through the upsert, which drops
/// nulls, so a child column a later change cleared kept its earlier value,
/// under the clock of the change that cleared it: every later copy of the
/// row ties, so nothing could repair it (#2644). The same gap the adopted
/// media fact clears close, and closed the same way.
void main() {
  late AppDatabase db;
  late SyncPayload base;
  late SyncPayload cleared;

  SyncService service() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
  );

  SyncPayload at(SyncData data, int exportedAt) => SyncPayload(
    version: 1,
    exportedAt: exportedAt,
    deviceId: 'peer',
    checksum: '',
    data: data,
    deletions: const {},
  );

  Future<String?> serial() async =>
      (await db
              .customSelect(
                "SELECT transmitter_serial FROM dive_tanks WHERE id = 't1'",
              )
              .getSingle())
          .read<String?>('transmitter_serial');

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, transmitter_serial) "
      "VALUES ('t1', 'd1', 'SER-1')",
    );
    final serializer = SyncDataSerializer();
    base = at(
      (await serializer.exportData(deviceId: 'peer', deletions: const [])).data,
      1000,
    );
    final tank = (await serializer.fetchRecord('diveTanks', 't1'))!;
    cleared = at(
      SyncData(
        diveTanks: [
          {
            ...tank,
            'transmitterSerial': null,
            'hlc': SyncClock.instance.issue(),
          },
        ],
      ),
      2000,
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test('in memory: a later change clears the column', () async {
    await service().debugAdoptInMemory([base, cleared]);
    expect(await serial(), isNull);
  });

  test('streaming: a later change clears the column', () async {
    await service().debugAdoptStreaming(const [], const [], [base, cleared]);
    expect(await serial(), isNull);
  });

  test('a library that never cleared it keeps the value', () async {
    await service().debugAdoptStreaming(const [], const [], [base]);
    expect(await serial(), 'SER-1');
  });
}
