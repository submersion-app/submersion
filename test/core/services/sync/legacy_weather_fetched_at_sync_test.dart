import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #4119. The v337 repair stamps nothing, so a sync store keeps the
/// milliseconds a peer wrote, and a peer below v337 goes on writing them. A
/// device past the rung never runs it again, and a new device never ran it at
/// all, so applying such a row has to repair it.
void main() {
  /// 2024-05-01T12:00:00Z.
  const inSeconds = 1714564800;
  const inMillis = inSeconds * 1000;

  late SyncDataSerializer serializer;

  setUp(() async {
    SyncClock.instance.reset();
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  SyncService buildService() =>
      SyncService(syncRepository: SyncRepository(), serializer: serializer);

  /// A dive as a peer below v337 publishes it, stamp in milliseconds.
  Future<SyncPayload> legacyPeerPayload() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'template', diveNumber: 1),
    );
    final template = (await serializer.fetchRecord('dives', 'template'))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      dives: [
        {
          ...template,
          'id': 'peer-dive',
          'weatherFetchedAt': inMillis,
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

  Future<void> expectRepaired() async {
    final row = (await serializer.fetchRecord('dives', 'peer-dive'))!;
    expect(row['weatherFetchedAt'], inSeconds);
  }

  test('a payload applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectRepaired();
  });

  test('a base file applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();
    final dir = await Directory.systemTemp.createTemp('legacy_weather');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));

    await buildService().debugApplyBaseFile(file.path);

    await expectRepaired();
  });
}
