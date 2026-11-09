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

/// Issue #4333. The v349 fill stamps nothing, so a sync store keeps the empty
/// water temperature a download left on the dive, and a peer below v349 goes
/// on publishing it. A device past the rung never runs it again, and a new
/// device never ran it at all, so applying such a dive has to fill it.
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

  /// The downloaded dive as this device holds it, its source carried, and
  /// the same dive as a peer below v349 publishes it: no water temperature.
  Future<SyncPayload> legacyPeerPayload() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(
        id: 'downloaded',
        diveNumber: 1,
        waterTemp: null,
      ),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'downloaded-src',
            diveId: 'downloaded',
            isPrimary: const Value(true),
            waterTemp: const Value(21.5),
            importedAt: DateTime.utc(2026, 11, 1),
            createdAt: DateTime.utc(2026, 11, 1),
          ),
        );
    final local = (await serializer.fetchRecord('dives', 'downloaded'))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      dives: [
        {
          ...local,
          'waterTemp': null,
          'updatedAt': updatedAt,
          'hlc': Hlc(updatedAt, 0, 'peer-dev').toString(),
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

  Future<void> expectFilled() async {
    final row = (await serializer.fetchRecord('dives', 'downloaded'))!;
    expect(row['waterTemp'], 21.5);
  }

  test('a payload applied from an older peer is filled', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectFilled();
  });

  test('a base file applied from an older peer is filled', () async {
    final payload = await legacyPeerPayload();
    final dir = await Directory.systemTemp.createTemp('legacy_water_temp');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));

    await buildService().debugApplyBaseFile(file.path);

    await expectFilled();
  });
}
