import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/utils/off_isolate.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  late ChangesetCodec codec;
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    codec = const ChangesetCodec();
  });
  tearDown(() => tearDownTestDatabase());

  test('changeset encode -> decode round-trips the payload', () async {
    final deviceId = await SyncRepository().getDeviceId();
    final payload = await serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: null,
      deletions: const [],
      seq: 3,
    );
    final bytes = await codec.encodeChangeset(payload);
    final back = await codec.decodeChangeset(bytes);
    expect(back.seq, 3);
    expect(SyncDataSerializer.checksumIsValid(back), isTrue);
  });

  test('base encode (chunked) -> reassemble -> decode round-trips', () async {
    final deviceId = await SyncRepository().getDeviceId();
    final payload = await serializer.exportData(
      deviceId: deviceId,
      deletions: const [],
    );
    final parts = BaseChunker.slice(
      await codec.encodeChangeset(payload),
      partSize: 64,
    );
    expect(parts.length, greaterThanOrEqualTo(1));
    final back = await codec.decodeChangeset(BaseChunker.reassemble(parts));
    expect(SyncDataSerializer.checksumIsValid(back), isTrue);
  });

  group('on a worker', () {
    // runOffIsolate reruns what a worker could not do, so a payload that cannot
    // cross to an isolate shows up here and nowhere else.
    final failures = <Object>[];
    var hops = 0;
    Future<R> recorded<R>(FutureOr<R> Function() work) async {
      hops++;
      try {
        return await Isolate.run(work);
      } catch (e) {
        failures.add(e);
        rethrow;
      }
    }

    setUp(() {
      failures.clear();
      hops = 0;
    });

    test('a real export crosses to a worker and back unchanged', () async {
      final deviceId = await SyncRepository().getDeviceId();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      final payload = await serializer.exportChangeset(
        deviceId: deviceId,
        hlcWatermark: null,
        deletions: const [],
        seq: 3,
      );
      expect(payload.data.dives, isNotEmpty);
      final worker = ChangesetCodec(
        offIsolateMinBytes: 0,
        offIsolateRunner: recorded,
      );

      final bytes = await worker.encodeChangeset(payload);
      final decoded = await worker.decodeVerifiedChangeset(bytes);

      expect(bytes, utf8.encode(jsonEncode(payload.toJson())));
      expect(decoded.checksumValid, isTrue);
      expect(decoded.payload.data.dives, payload.data.dives);
      expect(hops, 2);
      expect(failures, isEmpty);
    });

    test('a changeset past the threshold goes from writer to reader', () async {
      final db = DatabaseService.instance.database;
      final worker = ChangesetCodec(offIsolateRunner: recorded);
      final writer = ChangesetWriter(
        serializer,
        worker,
        PublishStateStore(db),
        compactionByteRatio: 1000.0,
        compactionMaxChangesets: 1 << 30,
      );
      final reader = ChangesetReader(worker, PeerCursorStore(db));
      final provider = FakeCloudStorageProvider();
      final folder = await provider.getOrCreateSyncFolder();
      final peerId = await SyncRepository().getDeviceId();
      Future<void> publish() => writer.publish(
        provider: provider,
        deviceId: peerId,
        folderId: folder,
        deletions: const [],
      );

      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await publish();
      final notes = 'x' * kOffIsolateMinBytes;
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(
          id: 'd2',
          diveNumber: 2,
        ).copyWith(notes: notes),
      );
      await publish();

      final applied = <SyncPayload>[];
      await reader.pull(
        provider: provider,
        selfDeviceId: 'reader-x',
        folderId: folder,
        apply: (p) async => applied.add(p),
        applyBaseFile: spyApplyBaseFile(applied),
      );

      final large = applied.last.data.dives.singleWhere((d) => d['id'] == 'd2');
      expect(large['notes'], notes);
      // One to write it, one to read it.
      expect(hops, 2);
      expect(failures, isEmpty);
    });
  });
}
