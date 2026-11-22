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
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Issue #4847. The v380 repairs move no sync clock, so a sync store keeps a
/// lone download non-primary and slotted, and a live series duplicating its
/// source's own, and a peer below v380 goes on publishing both. A device
/// past the rung never runs it again, and a new device never ran it at all,
/// so applying such rows has to repair them.
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

  SyncPayload payloadOf(SyncData data) => SyncPayload(
    version: syncFormatVersion,
    exportedAt: 9000,
    deviceId: 'peer-dev',
    checksum: sha256.convert(utf8.encode(jsonEncode(data.toJson()))).toString(),
    data: data,
    deletions: const {},
  );

  /// Later than anything the test has written locally, so the peer's row
  /// wins. Read when a payload is built, not when main() declares the tests:
  /// CI runs many files in one isolate, so a test can start minutes later.
  int peerUpdatedAt() => DateTime.now().millisecondsSinceEpoch + 60000;

  String peerHlc() => Hlc(
    DateTime.now().millisecondsSinceEpoch + 60000,
    0,
    'peer-dev',
  ).toString();

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: 'Computer $id',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  /// A 50 minute dive holding one 50 minute download, repaired here, and the
  /// same row as a peer below v380 publishes it: not primary, slotted.
  Future<SyncPayload> loneDownloadPayload() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'lone', diveNumber: 1),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'download',
            diveId: 'lone',
            isPrimary: const Value(true),
            duration: const Value(3000),
            importedAt: DateTime.utc(2021, 8, 2),
            createdAt: DateTime.utc(2021, 8, 2),
          ),
        );
    final local = (await serializer.fetchRecord(
      'diveDataSources',
      'download',
    ))!;
    return payloadOf(
      SyncData(
        diveDataSources: [
          {
            ...local,
            'isPrimary': false,
            'mergeSourceSlot': 0,
            'updatedAt': peerUpdatedAt(),
            'hlc': peerHlc(),
          },
        ],
      ),
    );
  }

  /// A dive whose download holds its own series and, demoted here, a stray
  /// one over the same minutes that a peer below v380 publishes live.
  Future<SyncPayload> duplicateSeriesPayload() async {
    await insertComputer('comp-a');
    await insertComputer('comp-b');
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'dup', diveNumber: 2),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'dup-src',
            diveId: 'dup',
            isPrimary: const Value(true),
            computerId: const Value('comp-a'),
            importedAt: DateTime.utc(2021, 8, 2),
            createdAt: DateTime.utc(2021, 8, 2),
          ),
        );
    // Real samples: a peer's series is applied only when its blob decodes
    // to the header it carries.
    final encoded = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 1500, depth: 30),
      ProfileSample(timestamp: 3000, depth: 0),
    ]);
    final summary = encoded.summary;
    for (final (id, computer, primary) in [
      ('own', 'comp-a', true),
      ('stray', 'comp-b', false),
    ]) {
      await db
          .into(db.diveProfileSeries)
          .insert(
            DiveProfileSeriesCompanion.insert(
              id: id,
              diveId: 'dup',
              computerId: Value(computer),
              sourceId: const Value('dup-src'),
              isPrimary: Value(primary),
              sampleCount: summary.sampleCount,
              startTimestamp: summary.startTimestamp,
              endTimestamp: summary.endTimestamp,
              maxDepth: summary.maxDepth,
              firstDepth: summary.firstDepth,
              lastDepth: summary.lastDepth,
              hasDecoType: Value(summary.hasDecoType),
              hasDecoStop: Value(summary.hasDecoStop),
              hasPositiveCeiling: Value(summary.hasPositiveCeiling),
              codecVersion: encoded.codecVersion,
              samples: encoded.bytes,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    final local = (await serializer.fetchRecord('diveProfileSeries', 'stray'))!;
    return payloadOf(
      SyncData(
        diveProfileSeries: [
          {
            ...local,
            'isPrimary': true,
            'updatedAt': peerUpdatedAt(),
            'hlc': peerHlc(),
          },
        ],
      ),
    );
  }

  Future<void> expectLoneRepaired() async {
    final row = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('download'))).getSingle();
    expect(row.isPrimary, isTrue);
    expect(row.mergeSourceSlot, isNull);
  }

  Future<void> expectStrayDemoted() async {
    final row = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.id.equals('stray'))).getSingle();
    expect(row.isPrimary, isFalse);
  }

  Future<void> applyBaseFile(SyncPayload payload) async {
    final dir = await Directory.systemTemp.createTemp('legacy_lone_download');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'base.json'));
    await file.writeAsBytes(utf8.encode(jsonEncode(payload.toJson())));
    await buildService().debugApplyBaseFile(file.path);
  }

  test('a lone download applied from an older peer is primary again', () async {
    final result = await buildService().debugApplyPayload(
      await loneDownloadPayload(),
    );

    expect(result.recordsApplied, greaterThan(0));

    await expectLoneRepaired();
  });

  test('a lone download in an older base file is primary again', () async {
    await applyBaseFile(await loneDownloadPayload());

    await expectLoneRepaired();
  });

  test('a duplicate series applied from an older peer is demoted', () async {
    final result = await buildService().debugApplyPayload(
      await duplicateSeriesPayload(),
    );

    expect(result.recordsApplied, greaterThan(0));

    await expectStrayDemoted();
  });

  test('a duplicate series in an older base file is demoted', () async {
    await applyBaseFile(await duplicateSeriesPayload());

    await expectStrayDemoted();
  });
}
