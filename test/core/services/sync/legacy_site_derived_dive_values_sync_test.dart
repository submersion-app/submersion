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

/// Issue #5040. A dive reads its site's altitude and water type, and the
/// v395 rung clears the copies linking a site made. The rung stamps nothing,
/// so a sync store keeps the copies. Applying such a dive has to clear them.
/// The rung's fill of empty entry and exit methods is not repeated: it would
/// put back a method the diver cleared on another device.
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

  /// A dive at a lake as a peer below v395 publishes it: the lake's
  /// altitude and water copied on, no entry method.
  Future<SyncPayload> legacyPeerPayload() async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'lake',
            name: 'Lake',
            altitude: const Value(450),
            waterType: const Value('fresh'),
            entryMethod: const Value('shore'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'linked', diveNumber: 1),
    );
    final local = (await serializer.fetchRecord('dives', 'linked'))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      dives: [
        {
          ...local,
          'siteId': 'lake',
          'altitude': 450.0,
          'waterType': 'fresh',
          'entryMethod': null,
          'exitMethod': null,
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
    final row = (await serializer.fetchRecord('dives', 'linked'))!;
    expect(row['siteId'], 'lake');
    expect(row['altitude'], isNull);
    expect(row['waterType'], isNull);
    expect(row['entryMethod'], isNull);
    expect(row['exitMethod'], isNull);
  }

  test('a payload applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectRepaired();
  });

  test('a base file applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();
    final dir = await Directory.systemTemp.createTemp('legacy_site_values');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));

    await buildService().debugApplyBaseFile(file.path);

    await expectRepaired();
  });
}
