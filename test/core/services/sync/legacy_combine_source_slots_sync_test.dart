import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #4367. The v356 stamp moves no sync clock, so a sync store keeps a
/// combined dive's source rows with no merge slot, and a peer below v356 goes
/// on publishing them that way. A device past the rung never runs it again,
/// and a new device never ran it at all, so applying such a row has to stamp
/// it.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    SyncClock.instance.reset();
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  SyncService buildService() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  /// The combined dive as this device holds it, its one carried row stamped,
  /// and the same row as a peer below v356 publishes it: with no slot.
  Future<SyncPayload> legacyPeerPayload() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'combined', diveNumber: 1),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'carried',
            diveId: 'combined',
            mergeSourceSlot: const Value(0),
            importedAt: DateTime.utc(2021, 8, 2),
            createdAt: DateTime.utc(2021, 8, 2),
          ),
        );
    final local = (await serializer.fetchRecord('diveDataSources', 'carried'))!;
    final stamp = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      diveDataSources: [
        {
          ...local,
          'mergeSourceSlot': null,
          'hlc': Hlc(stamp, 0, 'peer-dev').toString(),
        },
      ],
    );
    return SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: 'peer-dev',
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    );
  }

  Future<void> expectStamped() async {
    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('carried'))).getSingle();
    expect(row.mergeSourceSlot, 0);
  }

  test('a payload applied from an older peer is stamped', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectStamped();
  });

  test('a base file applied from an older peer is stamped', () async {
    final payload = await legacyPeerPayload();
    final dir = await Directory.systemTemp.createTemp('legacy_combine_slots');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));

    await buildService().debugApplyBaseFile(file.path);

    await expectStamped();
  });
}
