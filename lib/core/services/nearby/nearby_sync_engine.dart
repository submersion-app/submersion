import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_watermarks.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

/// The peer cursor provider id nearby sync records its progress under, so
/// it never touches a cloud backend's cursors.
const nearbyCursorProvider = 'nearby';

/// What the nearby sync protocol needs from this device's library. The
/// protocol is tested against a scripted fake; [DatabaseNearbySyncEngine]
/// is the real one.
abstract class NearbySyncEngine {
  Future<NearbyIdentity> identity();

  Future<NearbyWatermarks> watermarks();

  /// Stored bytes of the packed blobs a delta from [watermark] would carry;
  /// above [maxDeltaBlobBytes] the protocol streams a full copy instead.
  Future<int> deltaBlobBytes(String watermark);

  int get maxDeltaBlobBytes;

  Future<SyncPayload> exportDelta(String watermark);

  /// The caller owns and deletes the file.
  Future<StreamedBase> exportFull();

  Future<NearbyApplyResult> applyPayload(
    SyncPayload payload, {
    required String peerDeviceId,
  });

  Future<NearbyApplyResult> applyBaseFile(
    String path, {
    required String peerDeviceId,
    void Function(double fraction)? onProgress,
  });

  /// This device applied the peer's rows up to [appliedHlcHigh]; the oldest
  /// clock among them was [lowestAppliedHlc] (pulls the cloud watermark
  /// back so they are relayed).
  Future<void> recordApplied({
    required String peerDeviceId,
    required String? appliedHlcHigh,
    required String? lowestAppliedHlc,
  });

  /// The peer reported holding this device's rows up to
  /// [peerAppliedHlcHigh].
  Future<void> recordPeerAck({
    required String peerDeviceId,
    required String? peerAppliedHlcHigh,
  });

  Future<void> adoptEpoch(String epochId);

  /// The oldest clock held here from [writer], or null when none is.
  Future<String?> lowestClockOf(String writer);
}

class DatabaseNearbySyncEngine implements NearbySyncEngine {
  DatabaseNearbySyncEngine({
    required SyncService Function() syncService,
    required SyncDataSerializer serializer,
    required SyncRepository syncRepository,
    required PeerCursorStore peerCursors,
    required PublishStateStore publishStates,
    required NearbyPeerStore peers,
    required LibraryEpochStore epochStore,
    required AppDatabase database,
    DeviceIdentityResolver? resolveIdentity,
    this.maxDeltaBlobBytes = 16 * 1024 * 1024,
    DateTime Function() now = DateTime.now,
  }) : _sync = syncService,
       _serializer = serializer,
       _repo = syncRepository,
       _cursors = peerCursors,
       _publishStates = publishStates,
       _peers = peers,
       _epochs = epochStore,
       _db = database,
       _resolveIdentity =
           resolveIdentity ?? SyncDeviceMetadata(syncRepository).resolve,
       _now = now;

  /// Read on use: the service is rebuilt whenever the cloud backend
  /// changes, and holding one would rebuild the nearby link with it.
  final SyncService Function() _sync;
  final SyncDataSerializer _serializer;
  final SyncRepository _repo;
  final PeerCursorStore _cursors;
  final PublishStateStore _publishStates;
  final NearbyPeerStore _peers;
  final LibraryEpochStore _epochs;
  final AppDatabase _db;
  final DeviceIdentityResolver _resolveIdentity;
  final DateTime Function() _now;

  @override
  final int maxDeltaBlobBytes;

  Future<String?> _epochId() async =>
      _epochs.lastAcceptedEpochId ?? await _repo.getLastAcceptedEpochId();

  @override
  Future<NearbyIdentity> identity() async {
    final id = await _resolveIdentity();
    final dives = await _db.customSelect('SELECT 1 FROM dives LIMIT 1').get();
    return NearbyIdentity(
      deviceId: id.id,
      deviceName: id.name ?? 'Submersion',
      appVersion: id.appVersion ?? '',
      schemaVersion: AppDatabase.currentSchemaVersion,
      schemaFloor: AppDatabase.minimumCompatibleSchemaVersion,
      epochId: await _epochId(),
      hasDives: dives.isNotEmpty,
    );
  }

  @override
  Future<NearbyWatermarks> watermarks() async =>
      NearbyWatermarks(await _repo.maxRowHlcByWriter());

  @override
  Future<int> deltaBlobBytes(String watermark) =>
      _serializer.pendingSeriesBlobBytes(watermark);

  @override
  Future<SyncPayload> exportDelta(String watermark) async =>
      _serializer.exportChangeset(
        deviceId: await _repo.getDeviceId(),
        hlcWatermark: watermark,
        deletions: await _repo.getAllDeletions(),
        epochId: await _epochId(),
        childrenByOwnClock: true,
      );

  @override
  Future<StreamedBase> exportFull() async => _serializer.exportBaseToTempFile(
    deviceId: await _repo.getDeviceId(),
    deletions: await _repo.getAllDeletions(),
    epochId: await _epochId(),
  );

  Future<DateTime?> _lastSync(String peerDeviceId) async {
    final at = (await _peers.get(peerDeviceId))?.lastSyncedAt;
    return at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
  }

  @override
  Future<NearbyApplyResult> applyPayload(
    SyncPayload payload, {
    required String peerDeviceId,
  }) async => _sync().applyNearbyPayload(
    payload,
    lastSync: await _lastSync(peerDeviceId),
  );

  @override
  Future<NearbyApplyResult> applyBaseFile(
    String path, {
    required String peerDeviceId,
    void Function(double fraction)? onProgress,
  }) async => _sync().applyNearbyBaseFile(
    path,
    lastSync: await _lastSync(peerDeviceId),
    onProgress: onProgress,
  );

  @override
  Future<void> recordApplied({
    required String peerDeviceId,
    required String? appliedHlcHigh,
    required String? lowestAppliedHlc,
  }) async {
    // The relay floor first: the rows are applied whether or not the peer
    // is still paired, and the cloud must still carry them.
    if (lowestAppliedHlc != null) {
      await _publishStates.pullBackRelayFloor(lowestAppliedHlc);
    }
    // A peer unpaired during the session gets no cursor back.
    if (await _peers.get(peerDeviceId) == null) return;
    await _cursors.upsert(
      peerDeviceId: peerDeviceId,
      provider: nearbyCursorProvider,
      lastSeqApplied: 0,
      appliedHlcHigh: appliedHlcHigh,
    );
  }

  @override
  Future<void> recordPeerAck({
    required String peerDeviceId,
    required String? peerAppliedHlcHigh,
  }) async {
    if (peerAppliedHlcHigh != null) {
      await _peers.setPeerAck(peerDeviceId, peerAppliedHlcHigh);
    }
  }

  @override
  Future<String?> lowestClockOf(String writer) =>
      _repo.minRowHlcForWriter(writer);

  @override
  Future<void> adoptEpoch(String epochId) async {
    final id = await _resolveIdentity();
    await _epochs.setLastAccepted(
      LibraryEpochMarker(
        epochId: epochId,
        replacedAt: _now().millisecondsSinceEpoch,
        deviceId: id.id,
        deviceName: id.name,
        appVersion: id.appVersion,
      ),
    );
    await _repo.setLastAcceptedEpochId(epochId);
  }
}
