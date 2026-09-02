// Legacy sample entities (dive_profiles / tank_pressure_profiles) become
// inbound-only as of v182 (plan 2d, task 2): a device never exports its own
// row-per-sample data any more (it writes series instead, see plan 2b/2c),
// but an older peer that has not migrated yet still publishes row-per-sample
// arrays, and those must keep applying so its data is not silently dropped.
// A post-merge hook packs whatever legacy rows land locally into series.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/legacy_sample_staging.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

domain.Dive _dive(String id, List<domain.DiveProfilePoint> profile) =>
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), profile: profile);

const _twoPoints = [
  domain.DiveProfilePoint(timestamp: 0, depth: 5.0),
  domain.DiveProfilePoint(timestamp: 60, depth: 10.0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export: legacy sample entities never leave this device', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() => tearDownTestDatabase());

    test('exportChangeset carries no legacy sample entities', () async {
      await DiveRepository().createDive(_dive('d1', _twoPoints));
      final payload = await SyncDataSerializer().exportChangeset(
        deviceId: 'me',
        hlcWatermark: null,
        deletions: const [],
      );
      final data = payload.data;
      expect(data.toJson().containsKey('diveProfiles'), isFalse);
      expect(data.toJson().containsKey('tankPressureProfiles'), isFalse);
      expect(data.diveProfileSeries, hasLength(1));
    });

    test('SyncData.fromJson still parses the legacy keys', () {
      final data = SyncData.fromJson({
        'diveProfiles': [
          {'id': 'x'},
        ],
        'tankPressureProfiles': [
          {'id': 'y'},
        ],
      });
      expect(data.diveProfiles.single['id'], 'x');
      expect(data.tankPressureProfiles.single['id'], 'y');
    });
  });

  group('inbound: a peer publishing legacy sample rows', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
    });

    tearDown(() => DatabaseService.instance.resetForTesting());

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );

    /// Builds the payload JSON both helpers below publish: [dataJson] is the
    /// raw `data` section a peer still on row-per-sample tables would send,
    /// legacy `diveProfiles` / `tankPressureProfiles` keys included.
    /// `SyncPayload.toJson` (and so `ChangesetCodec.encodeChangeset` /
    /// `encodeBaseParts`, which route through it) calls `data.toJson` under
    /// the hood, which drops those keys (inbound only) before the bytes are
    /// ever built, so both helpers assemble the wire bytes from raw JSON
    /// instead of going through a `SyncPayload` object.
    Map<String, dynamic> buildPayloadJson(
      Map<String, dynamic> dataJson,
      String peerId, {
      int? seq,
      int? baseSeq,
    }) {
      final checksum = sha256
          .convert(utf8.encode(jsonEncode(dataJson)))
          .toString();
      return <String, dynamic>{
        'version': syncFormatVersion,
        'exportedAt': 9000,
        'deviceId': peerId,
        'lastSyncTimestamp': null,
        'checksum': checksum,
        'data': dataJson,
        'deletions': <String, dynamic>{},
        'uploadNonce': null,
        'epochId': null,
        'seq': seq,
        'baseSeq': baseSeq,
        'sinceHlc': null,
        'toHlc': null,
      };
    }

    /// Publishes [dataJson] as [peerId]'s single CHANGESET (seq 1, no base)
    /// and pulls it through the real merge path: the shape an
    /// already-known peer's small incremental update takes
    /// (`_applyRemotePayloadInner`, applied via `mergeOrder`). Returns the
    /// sync result so a caller can inspect `recordsSynced`. The staging
    /// table is emptied by the packer regardless of outcome, so it is no
    /// longer possible to confirm a legacy row applied by querying a table
    /// for it afterwards.
    Future<SyncResult> pullPeerPayload(
      Map<String, dynamic> dataJson,
      String peerId,
    ) async {
      final payloadJson = buildPayloadJson(dataJson, peerId, seq: 1);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payloadJson)));
      final folder = await cloud.getOrCreateSyncFolder();
      await cloud.uploadFile(
        bytes,
        ChangesetLogLayout.changesetName(peerId, 1),
        folderId: folder,
      );
      final manifest = SyncManifest(
        deviceId: peerId,
        provider: cloud.providerId,
        headSeq: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await cloud.uploadFile(
        manifest.toBytes(),
        ChangesetLogLayout.manifestName(peerId),
        folderId: folder,
      );
      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));
      return result;
    }

    /// Publishes [dataJson] as [peerId]'s BASE (baseSeq 1, one part, headSeq
    /// 1) and pulls it through the real merge path: the "first contact"
    /// shape for a peer this device has never synced with before (cold
    /// start), applied via the streaming base-file path
    /// (`_applyRemoteBaseFile*`), which reads `_baseApplyEntityFlags`
    /// (`entityHasUpdatedAt` unioned with `inboundOnlyLegacyEntities`) to
    /// decide which tables to read off the wire.
    Future<void> pullPeerBasePayload(
      Map<String, dynamic> dataJson,
      String peerId,
    ) async {
      final payloadJson = buildPayloadJson(dataJson, peerId, baseSeq: 1);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payloadJson)));
      final folder = await cloud.getOrCreateSyncFolder();
      await cloud.uploadFile(
        bytes,
        ChangesetLogLayout.basePartName(peerId, 1, 0),
        folderId: folder,
      );
      final manifest = SyncManifest(
        deviceId: peerId,
        provider: cloud.providerId,
        baseSeq: 1,
        basePartCount: 1,
        baseBytes: bytes.length,
        baseChecksum: BaseChunker.checksum(bytes),
        basePartChecksums: [BaseChunker.checksum(bytes)],
        headSeq: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await cloud.uploadFile(
        manifest.toBytes(),
        ChangesetLogLayout.manifestName(peerId),
        folderId: folder,
      );
      final result = await buildService().performSync();
      expect(result.status, isNot(SyncResultStatus.error));
    }

    test(
      'a v181 peer payload with legacy rows for a new dive lands as a series',
      () async {
        await DiveRepository().createDive(_dive('template', const []));
        final diveRow =
            Map<String, dynamic>.from(
                (await SyncDataSerializer().fetchRecord('dives', 'template'))!,
              )
              ..['id'] = 'd-old'
              ..['hlc'] = const Hlc(9000, 0, 'peer-181').toString();
        final profiles = [
          {
            'id': 'p1',
            'diveId': 'd-old',
            'timestamp': 0,
            'depth': 0.0,
            'isPrimary': true,
          },
          {
            'id': 'p2',
            'diveId': 'd-old',
            'timestamp': 60,
            'depth': 12.0,
            'isPrimary': true,
          },
        ];
        final data = SyncData(dives: [diveRow], diveProfiles: profiles);
        // SyncData.fromJson(data.toJson()) would DROP diveProfiles (inbound
        // only), so build the payload data section by hand.
        final dataJson = {...data.toJson(), 'diveProfiles': profiles};

        await pullPeerPayload(dataJson, 'peer-181');

        final series = await ProfileSeriesRepository().getSeriesForDive(
          'd-old',
        );
        expect(series, hasLength(1));
        expect(series.single.samples.map((s) => s.depth), [0.0, 12.0]);
        expect(
          series.single.id,
          profileSeriesMigratedId(
            diveId: 'd-old',
            computerId: null,
            sourceId: null,
            isPrimary: true,
          ),
        );
      },
    );

    test(
      'a payload written before v151 restores with null millivolts',
      () async {
        // v151 is when the O2 cell millivolt columns (o2SensorMv1..6)
        // joined the wire format; a peer on an older build never sends
        // those keys at all, not even as explicit nulls.
        await DiveRepository().createDive(_dive('template-mv', const []));
        final diveRow =
            Map<String, dynamic>.from(
                (await SyncDataSerializer().fetchRecord(
                  'dives',
                  'template-mv',
                ))!,
              )
              ..['id'] = 'd-mv-old'
              ..['hlc'] = const Hlc(9000, 0, 'peer-pre-v151').toString();
        final profiles = [
          {
            'id': 'p-mv',
            'diveId': 'd-mv-old',
            'timestamp': 0,
            'depth': 8.0,
            'isPrimary': true,
          },
        ];
        final data = SyncData(dives: [diveRow], diveProfiles: profiles);
        final dataJson = {...data.toJson(), 'diveProfiles': profiles};

        await pullPeerPayload(dataJson, 'peer-pre-v151');

        final series = await ProfileSeriesRepository().getSeriesForDive(
          'd-mv-old',
        );
        expect(series, hasLength(1));
        final sample = series.single.samples.single;
        expect(sample.depth, 8.0);
        expect(sample.o2SensorMv1, isNull);
        expect(sample.o2SensorMv6, isNull);
      },
    );

    test("a legacy peer's first-contact BASE snapshot lands its sample rows "
        'as series', () async {
      await DiveRepository().createDive(_dive('template-base', const []));
      final diveRow =
          Map<String, dynamic>.from(
              (await SyncDataSerializer().fetchRecord(
                'dives',
                'template-base',
              ))!,
            )
            ..['id'] = 'd-base-old'
            ..['hlc'] = const Hlc(9000, 0, 'peer-181-base').toString();
      final profiles = [
        {
          'id': 'p1-base',
          'diveId': 'd-base-old',
          'timestamp': 0,
          'depth': 3.0,
          'isPrimary': true,
        },
        {
          'id': 'p2-base',
          'diveId': 'd-base-old',
          'timestamp': 60,
          'depth': 15.0,
          'isPrimary': true,
        },
      ];
      final data = SyncData(dives: [diveRow], diveProfiles: profiles);
      final dataJson = {...data.toJson(), 'diveProfiles': profiles};

      await pullPeerBasePayload(dataJson, 'peer-181-base');

      final series = await ProfileSeriesRepository().getSeriesForDive(
        'd-base-old',
      );
      expect(series, hasLength(1));
      expect(series.single.samples.map((s) => s.depth), [3.0, 15.0]);
      expect(
        series.single.id,
        profileSeriesMigratedId(
          diveId: 'd-base-old',
          computerId: null,
          sourceId: null,
          isPrimary: true,
        ),
      );
    });

    test(
      'legacy rows for a dive that already has series are ignored',
      () async {
        await DiveRepository().createDive(_dive('d1', _twoPoints));
        final before = (await ProfileSeriesRepository().getSeriesForDive(
          'd1',
        )).single;

        final profiles = [
          {
            'id': 'p-stale',
            'diveId': 'd1',
            'timestamp': 0,
            'depth': 99.0,
            'isPrimary': true,
          },
        ];
        final data = SyncData(diveProfiles: profiles);
        final dataJson = {...data.toJson(), 'diveProfiles': profiles};

        final result = await pullPeerPayload(dataJson, 'peer-181b');

        // The merge itself must have succeeded (legacy rows still apply
        // through the kept upsertRecords case, which stages them): this is
        // the packer's dive-already-has-a-series gate skipping the pack, not
        // a failed merge that never staged the row at all. The staging table
        // is emptied by the packer either way, so `recordsSynced` (counted
        // when the row is staged, before packing runs) is the only way left
        // to see that the row was actually applied.
        expect(result.recordsSynced, greaterThanOrEqualTo(1));

        final after = (await ProfileSeriesRepository().getSeriesForDive(
          'd1',
        )).single;
        expect(after.id, before.id);
        expect(
          after.samples.map((s) => s.depth),
          before.samples.map((s) => s.depth),
        );
      },
    );

    test('a packer failure during the merge does not fail the sync or lose '
        'the applied dive row', () async {
      // The pack runs inside the deferred-FK merge transaction with no
      // try around it in the old code, so a throw here rolled back the
      // whole payload while the changeset reader's cursor stayed put: the
      // next sync would replay and throw the same way forever. Simulating
      // the failure the same way backstop_resilience_test.dart does for
      // the beforeOpen backstop (a series table shaped so the packer's
      // INSERT cannot bind every column) exercises the sync-time guard
      // instead.
      await DiveRepository().createDive(_dive('template-pack-fail', const []));
      final diveRow =
          Map<String, dynamic>.from(
              (await SyncDataSerializer().fetchRecord(
                'dives',
                'template-pack-fail',
              ))!,
            )
            ..['id'] = 'd-pack-fail'
            ..['hlc'] = const Hlc(9000, 0, 'peer-pack-fail').toString();
      final profiles = [
        {
          'id': 'p-pack-fail',
          'diveId': 'd-pack-fail',
          'timestamp': 0,
          'depth': 4.0,
          'isPrimary': true,
        },
      ];
      final data = SyncData(dives: [diveRow], diveProfiles: profiles);
      final dataJson = {...data.toJson(), 'diveProfiles': profiles};

      final db = DatabaseService.instance.database;
      await db.customStatement('DROP TABLE dive_profile_series');
      await db.customStatement('''
          CREATE TABLE dive_profile_series (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 1
          )
        ''');

      await pullPeerPayload(dataJson, 'peer-pack-fail');

      final landed = await db
          .customSelect(
            'SELECT 1 FROM dives WHERE id = ?',
            variables: [Variable.withString('d-pack-fail')],
          )
          .get();
      expect(landed, hasLength(1));
    });
  });

  group('adopt: a replace-adopt from a legacy peer', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() => tearDownTestDatabase());

    SyncService buildService() => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
    );

    test(
      "adopting a legacy peer's base lands its sample rows as series",
      () async {
        await DiveRepository().createDive(_dive('template-adopt', const []));
        final diveRow =
            Map<String, dynamic>.from(
                (await SyncDataSerializer().fetchRecord(
                  'dives',
                  'template-adopt',
                ))!,
              )
              ..['id'] = 'd-adopt-old'
              ..['hlc'] = const Hlc(9000, 0, 'peer-181-adopt').toString();
        final profiles = [
          {
            'id': 'p1-adopt',
            'diveId': 'd-adopt-old',
            'timestamp': 0,
            'depth': 6.0,
            'isPrimary': true,
          },
          {
            'id': 'p2-adopt',
            'diveId': 'd-adopt-old',
            'timestamp': 60,
            'depth': 20.0,
            'isPrimary': true,
          },
        ];
        final data = SyncData(dives: [diveRow], diveProfiles: profiles);
        // SyncPayload.toJson (and so SyncDataSerializer.serializePayload,
        // which the other adopt tests use to write a base file) routes
        // through data.toJson, which drops diveProfiles (inbound only), so
        // the payload bytes are built by hand instead, exactly as the
        // changeset/base peer-sync tests above do.
        final dataJson = {...data.toJson(), 'diveProfiles': profiles};
        final payloadJson = <String, dynamic>{
          'version': syncFormatVersion,
          'exportedAt': 9000,
          'deviceId': 'peer-181-adopt',
          'lastSyncTimestamp': null,
          'checksum': sha256
              .convert(utf8.encode(jsonEncode(dataJson)))
              .toString(),
          'data': dataJson,
          'deletions': <String, dynamic>{},
          'uploadNonce': null,
          'epochId': null,
          'seq': null,
          'baseSeq': null,
          'sinceHlc': null,
          'toHlc': null,
        };

        final tmpDir = await Directory.systemTemp.createTemp('adopt_legacy');
        final tmp = File('${tmpDir.path}/base.json');
        await tmp.writeAsBytes(utf8.encode(jsonEncode(payloadJson)));
        // debugAdoptStreaming drives the same production path
        // (_adoptApplyStreaming) sync_adopt_streaming_parity_test.dart and
        // sync_adopt_builtin_dive_types_test.dart use: no confirmation
        // callback or mode flag, just base file paths plus their
        // exportedAt and any in-memory changesets layered on top.
        await buildService().debugAdoptStreaming([tmp.path], [9000], const []);
        await tmpDir.delete(recursive: true);

        final series = await ProfileSeriesRepository().getSeriesForDive(
          'd-adopt-old',
        );
        expect(series, hasLength(1));
        expect(series.single.samples.map((s) => s.depth), [6.0, 20.0]);
        expect(
          series.single.id,
          profileSeriesMigratedId(
            diveId: 'd-adopt-old',
            computerId: null,
            sourceId: null,
            isPrimary: true,
          ),
        );
      },
    );

    test('adopting a base that carries only the missing parent drains the rows '
        'staged by an earlier changeset', () async {
      // A pre-v183 peer published diveProfiles for a dive before the dive
      // itself synced, so the rows staged and were kept for a later apply.
      // The cloud base was written by an upgraded peer: it carries the
      // dive but no legacy rows at all, so only the parent flag can tell
      // the packer that the block is gone.
      await SyncDataSerializer().upsertRecord('diveProfiles', {
        'id': 'p-orphan',
        'diveId': 'd-late-parent',
        'timestamp': 0,
        'depth': 7.0,
        'isPrimary': true,
      });
      expect(
        await SyncDataSerializer().hasStagedLegacySamples(),
        isTrue,
        reason: 'the row stages even though its dive has not arrived',
      );

      await DiveRepository().createDive(_dive('template-late', const []));
      final diveRow =
          Map<String, dynamic>.from(
              (await SyncDataSerializer().fetchRecord(
                'dives',
                'template-late',
              ))!,
            )
            ..['id'] = 'd-late-parent'
            ..['hlc'] = const Hlc(9000, 0, 'peer-183-adopt').toString();
      final dataJson = SyncData(dives: [diveRow]).toJson();
      final payloadJson = <String, dynamic>{
        'version': syncFormatVersion,
        'exportedAt': 9000,
        'deviceId': 'peer-183-adopt',
        'lastSyncTimestamp': null,
        'checksum': sha256
            .convert(utf8.encode(jsonEncode(dataJson)))
            .toString(),
        'data': dataJson,
        'deletions': <String, dynamic>{},
        'uploadNonce': null,
        'epochId': null,
        'seq': null,
        'baseSeq': null,
        'sinceHlc': null,
        'toHlc': null,
      };

      final tmpDir = await Directory.systemTemp.createTemp('adopt_parent');
      final tmp = File('${tmpDir.path}/base.json');
      await tmp.writeAsBytes(utf8.encode(jsonEncode(payloadJson)));
      await buildService().debugAdoptStreaming([tmp.path], [9000], const []);
      await tmpDir.delete(recursive: true);

      final series = await ProfileSeriesRepository().getSeriesForDive(
        'd-late-parent',
      );
      expect(
        series,
        hasLength(1),
        reason: 'the adopt delivered the parent that was blocking the pack',
      );
      expect(series.single.samples.single.depth, 7.0);
      expect(await SyncDataSerializer().hasStagedLegacySamples(), isFalse);
    });
  });

  group('serializer: direct upsertRecord/upsertRecords staging paths', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() => tearDownTestDatabase());

    test("upsertRecord('diveProfiles', ...) stages a single row that packs "
        'into a series', () async {
      await DiveRepository().createDive(_dive('d-single', const []));

      await SyncDataSerializer().upsertRecord('diveProfiles', {
        'id': 'p-single',
        'diveId': 'd-single',
        'timestamp': 0,
        'depth': 5.0,
        'isPrimary': true,
      });

      final db = DatabaseService.instance.database;
      final report = await packStagedLegacyRows(db);
      expect(report.profileSeries, 1);

      final series = await ProfileSeriesRepository().getSeriesForDive(
        'd-single',
      );
      expect(series, hasLength(1));
      expect(series.single.samples.single.depth, 5.0);
    });

    test("upsertRecord('tankPressureProfiles', ...) stages a single row that "
        'packs into a tank pressure series', () async {
      await DiveRepository().createDive(_dive('d-tank-single', const []));
      final db = DatabaseService.instance.database;
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'tank-single',
              diveId: 'd-tank-single',
            ),
          );

      await SyncDataSerializer().upsertRecord('tankPressureProfiles', {
        'id': 'q-single',
        'diveId': 'd-tank-single',
        'tankId': 'tank-single',
        'timestamp': 0,
        'pressure': 200.0,
      });

      final report = await packStagedLegacyRows(db);
      expect(report.tankSeries, 1);

      final series = await TankPressureSeriesRepository().getSeriesForDive(
        'd-tank-single',
      );
      expect(series, hasLength(1));
      expect(series.single.samples.single.pressure, 200.0);
    });

    test("upsertRecords('tankPressureProfiles', ...) batch-stages multiple "
        'rows that pack into one tank pressure series', () async {
      await DiveRepository().createDive(_dive('d-tank-batch', const []));
      final db = DatabaseService.instance.database;
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 'tank-batch', diveId: 'd-tank-batch'),
          );

      await SyncDataSerializer().upsertRecords('tankPressureProfiles', [
        {
          'id': 'q-batch-1',
          'diveId': 'd-tank-batch',
          'tankId': 'tank-batch',
          'timestamp': 0,
          'pressure': 200.0,
        },
        {
          'id': 'q-batch-2',
          'diveId': 'd-tank-batch',
          'tankId': 'tank-batch',
          'timestamp': 60,
          'pressure': 180.0,
        },
      ]);

      final report = await packStagedLegacyRows(db);
      expect(report.tankSeries, 1);

      final series = await TankPressureSeriesRepository().getSeriesForDive(
        'd-tank-batch',
      );
      expect(series, hasLength(1));
      expect(series.single.samples.map((s) => s.pressure), [200.0, 180.0]);
    });
  });
}
