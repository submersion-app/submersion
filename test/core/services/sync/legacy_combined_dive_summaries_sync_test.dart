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

/// Issue #4136. The v340 repair stamps nothing, so a sync store keeps the
/// first segment's values a Combine wrote, and a peer below v340 goes on
/// publishing them. A device past the rung never runs it again, and a new
/// device never ran it at all, so applying such a dive has to repair it.
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

  Future<void> insertSegmentSource(
    String id, {
    required DateTime entry,
    required double waterTemp,
    required double otu,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: 'combined',
          mergeSourceSlot: const Value(0),
          entryTime: Value(entry),
          exitTime: Value(entry.add(const Duration(minutes: 20))),
          waterTemp: Value(waterTemp),
          otu: Value(otu),
          importedAt: DateTime.utc(2021, 8, 2),
          createdAt: DateTime.utc(2021, 8, 2),
        ),
      );

  /// The combined dive as this device holds it, its segments' sources
  /// carried, and the same dive as a peer below v340 publishes it: holding
  /// the first segment's water temperature and OTU.
  Future<SyncPayload> legacyPeerPayload() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'combined', diveNumber: 1),
    );
    await insertSegmentSource(
      'combined-1',
      entry: DateTime.utc(2021, 8, 1, 11, 47),
      waterTemp: 16,
      otu: 30,
    );
    await insertSegmentSource(
      'combined-2',
      entry: DateTime.utc(2021, 8, 1, 12, 15),
      waterTemp: 8,
      otu: 45,
    );
    final local = (await serializer.fetchRecord('dives', 'combined'))!;
    final updatedAt = DateTime.now().millisecondsSinceEpoch + 60000;
    final data = SyncData(
      dives: [
        {
          ...local,
          'waterTemp': 16.0,
          'otu': 30.0,
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
    final row = (await serializer.fetchRecord('dives', 'combined'))!;
    expect(row['waterTemp'], 8);
    expect(row['otu'], 75);
  }

  test('a payload applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();

    await buildService().debugApplyPayload(payload);

    await expectRepaired();
  });

  test('a base file applied from an older peer is repaired', () async {
    final payload = await legacyPeerPayload();
    final dir = await Directory.systemTemp.createTemp('legacy_combined');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));

    await buildService().debugApplyBaseFile(file.path);

    await expectRepaired();
  });
}
