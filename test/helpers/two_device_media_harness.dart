import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' show Fake;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/gallery_cloud_id_backfill.dart';
import 'package:submersion/features/media/data/services/gallery_origin_backfill.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/media_tile_resolver.dart';
import 'package:submersion/features/media/data/services/media_verification_sweep.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_orphan_reconciler.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_store_preflight.dart';
import 'package:submersion/features/media_store/data/media_store_worker.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';

import 'fake_cloud_storage_provider.dart';
import 'fake_photo_picker_service.dart';
import 'in_memory_media_object_store.dart';

/// What a grid tile would draw for a row on this device.
enum TileOutcome { native, store, unavailable }

/// A file on another device: it does not exist here, whatever the disk says.
///
/// Both harness devices share one real filesystem, so without this device B
/// would read device A's originals straight off the disk and the store
/// fallback would never be exercised. Only the members the resolvers touch
/// are implemented; anything else throws, which is the right answer for a
/// path that should have been treated as absent.
class _ForeignFile extends Fake implements File {
  _ForeignFile(this.path);

  @override
  final String path;

  @override
  Future<bool> exists() async => false;

  @override
  bool existsSync() => false;

  @override
  Future<Uint8List> readAsBytes() =>
      Future.error(FileSystemException('On another device', path));

  @override
  Uint8List readAsBytesSync() =>
      throw FileSystemException('On another device', path);

  @override
  Future<int> length() =>
      Future.error(FileSystemException('On another device', path));

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream.error(FileSystemException('On another device', path));
}

/// Plain dart:io behaviour, for the paths that are NOT foreign. Nesting a
/// zone with these overrides is how a real [File] is created from inside
/// another override without recursing into it.
final class _PassthroughIO extends IOOverrides {}

/// Bookmark storage that never resolves: the harness runs the plain-path
/// branch of [LocalFileResolver] on every host.
class _NullBookmarkStorage extends LocalBookmarkStorage {
  _NullBookmarkStorage() : super(storage: null);

  @override
  Future<Uint8List?> read(String ref) async => null;
}

/// Two complete devices sharing one sync backend and one media store.
///
/// The app database and the sync clock are process singletons, so the two
/// devices take turns: every [HarnessDevice] operation calls
/// [HarnessDevice.activate] first, which swaps its database into
/// [DatabaseService] and resets the clock. Nothing here is concurrent; that
/// is a limitation of the app's singletons, not of the scenarios.
///
/// Shared on purpose: the fake cloud (the sync folder), the object store
/// (the bucket) and, because SharedPreferences is process-global, the media
/// store attach state. Both devices are attached to the same store id, which
/// is the configuration every scenario needs.
class TwoDeviceMediaHarness {
  TwoDeviceMediaHarness._(this.cloud, this.bucket, this.storeId);

  final FakeCloudStorageProvider cloud;
  final InMemoryMediaObjectStore bucket;
  final String storeId;
  late final HarnessDevice a;
  late final HarnessDevice b;

  static Future<TwoDeviceMediaHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    // Two LocalCacheDatabase instances over two memory executors are the
    // point of this harness; drift's warning is about sharing one executor.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final cloud = FakeCloudStorageProvider();
    final bucket = InMemoryMediaObjectStore();
    final marker = (await StoreMarkerStore(store: bucket).ensure()).marker;
    final attach = MediaStoreAttachState();
    await attach.setAttached(
      marker.storeId,
      providerType: CloudProviderType.s3,
    );
    final h = TwoDeviceMediaHarness._(cloud, bucket, marker.storeId);
    h.a = await HarnessDevice._create(h, 'Device A', attach);
    h.b = await HarnessDevice._create(h, 'Device B', attach);
    return h;
  }

  Future<void> dispose() async {
    await a._dispose();
    await b._dispose();
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  }
}

class HarnessDevice {
  HarnessDevice._(this._harness, this.name);

  final TwoDeviceMediaHarness _harness;
  final String name;

  late final AppDatabase db;
  late final LocalCacheDatabase cacheDb;
  late final Directory root;
  late final String deviceId;
  late final FakePhotoPickerService gallery;
  late final MediaCacheStore cache;
  late final MediaTransferQueueRepository queue;
  late final LocalAssetCacheRepository assetCache;
  late final MediaSourceResolverRegistry registry;
  late final MediaStoreResolver storeResolver;
  late final MediaTileResolver tileResolver;
  late MediaStoreWorker worker;

  /// The preflight the worker consults before every entry. Defaults to the
  /// production [MediaStorePreflight]; a scenario replaces it to script a
  /// marker failure on one device. Null admits the drain.
  late Future<MediaTransferHoldKind?> Function() preflight;

  static Future<HarnessDevice> _create(
    TwoDeviceMediaHarness h,
    String name,
    MediaStoreAttachState attach,
  ) async {
    final d = HarnessDevice._(h, name);
    d.db = AppDatabase(NativeDatabase.memory());
    d.cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    d.root = await Directory.systemTemp.createTemp(
      'two_device_${name.replaceAll(' ', '_')}_',
    );
    d.gallery = FakePhotoPickerService();
    await d.activate();
    d.deviceId = await SyncRepository().getDeviceId();
    await d.db
        .into(d.db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver1'),
            name: Value('diver1'),
            isDefault: Value(true),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await d.db
        .into(d.db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver2'),
            name: Value('diver2'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    d.cache = MediaCacheStore(
      database: d.cacheDb,
      root: Directory('${d.root.path}/cache')..createSync(),
    );
    d.queue = MediaTransferQueueRepository(database: d.cacheDb);
    d.assetCache = LocalAssetCacheRepository(database: d.cacheDb);
    d.registry = MediaSourceResolverRegistry({
      MediaSourceType.platformGallery: PlatformGalleryResolver(
        resolutionService: AssetResolutionService(
          cacheRepository: d.assetCache,
          photoPickerService: d.gallery,
          cloudIdentifiers: d.gallery,
        ),
        assetReader: d.gallery,
        localDeviceId: () async => d.deviceId,
      ),
      MediaSourceType.localFile: LocalFileResolver(
        bookmarkStorage: _NullBookmarkStorage(),
        platform: LocalMediaPlatform(),
        exifExtractor: ExifExtractor(),
        localDeviceId: () async => d.deviceId,
      ),
    });
    d.storeResolver = MediaStoreResolver(store: h.bucket, cache: d.cache);
    d.tileResolver = MediaTileResolver(
      registry: d.registry,
      remote: () async => d.storeResolver,
    );
    d.preflight = MediaStorePreflight(
      attachState: attach,
      store: h.bucket,
      attachedStoreId: h.storeId,
    ).check;
    d.worker = d._buildWorker();
    return d;
  }

  MediaStoreWorker _buildWorker() => MediaStoreWorker(
    queue: queue,
    pipeline: MediaUploadPipeline(
      mediaRepository: MediaRepository(),
      queue: queue,
      store: _harness.bucket,
      registry: registry,
      cache: cache,
    ),
    preflight: () => preflight(),
  );

  /// Makes this device the live one. Idempotent and cheap.
  Future<void> activate() async {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
  }

  bool _isForeign(String path) {
    for (final other in [_harness.a, _harness.b]) {
      if (identical(other, this)) continue;
      if (path.startsWith(other.root.path)) return true;
    }
    return false;
  }

  /// Runs [body] with this device's view of the disk: every path under the
  /// other device's root reads as absent. Public so a test that drives a
  /// resolver directly (the health reporter, a verifier) sees the same disk
  /// the device's own operations do.
  Future<T> onThisDisk<T>(Future<T> Function() body) => IOOverrides.runZoned(
    body,
    createFile: (path) => _isForeign(path)
        ? _ForeignFile(path)
        : IOOverrides.runWithIOOverrides(() => File(path), _PassthroughIO()),
  );

  Future<String> createDive({String diverId = 'diver1', DateTime? at}) async {
    await activate();
    final when = (at ?? DateTime(2026, 7, 1, 10)).millisecondsSinceEpoch;
    final id = 'dive-${name.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(when),
            createdAt: Value(when),
            updatedAt: Value(when),
          ),
        );
    await SyncRepository().markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: when,
    );
    return id;
  }

  Future<String> linkFile(
    List<int> bytes, {
    required String diveId,
    String name = 'reef.jpg',
    DateTime? takenAt,
  }) async {
    await activate();
    final dir = Directory('${root.path}/files')..createSync(recursive: true);
    final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    final when = takenAt ?? DateTime(2026, 7, 1, 10, 30);
    final created = await MediaRepository().createMedia(
      MediaItem(
        id: '',
        diveId: diveId,
        mediaType: name.endsWith('.mov') ? MediaType.video : MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: file.path,
        localPath: file.path,
        originalFilename: name,
        takenAt: when,
        createdAt: when,
        updatedAt: when,
      ),
    );
    return created.id;
  }

  Future<String> linkGalleryPhoto(
    FakeGalleryAsset asset, {
    required String diveId,
  }) async {
    await activate();
    gallery.add(asset);
    // As MediaImportService stamps it at link time (spec 6.2). The counter
    // is reset so tests count only resolution's lookups.
    final cloudIds = await gallery.cloudIdentifiers([asset.id]);
    gallery.cloudIdCalls = 0;
    final created = await MediaRepository().createMedia(
      MediaItem(
        id: '',
        diveId: diveId,
        platformAssetId: asset.id,
        cloudAssetId: cloudIds[asset.id],
        mediaType: asset.type == AssetType.video
            ? MediaType.video
            : MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        originalFilename: asset.filename,
        takenAt: asset.takenAt,
        createdAt: asset.takenAt,
        updatedAt: asset.takenAt,
      ),
    );
    return created.id;
  }

  Future<void> enqueueUpload(String mediaId) async {
    await activate();
    await queue.enqueueUpload(mediaId: mediaId);
  }

  /// One full, awaited drain. Never `enqueueAndKick`: its background drain is
  /// nondeterministic in a test.
  Future<void> drain() async {
    await activate();
    await onThisDisk(() => worker.drain());
  }

  /// Models the app being killed and relaunched: the queue survives, the
  /// worker does not.
  Future<void> relaunch() async {
    await activate();
    worker.dispose();
    worker = _buildWorker();
  }

  Future<SyncResult> sync({bool expectSuccess = true}) async {
    await activate();
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: _harness.cloud,
      onMediaResolutionHints: assetCache.applyResolutionHints,
    ).performSync();
    if (expectSuccess && !result.isSuccess) {
      throw StateError('$name sync failed: ${result.status} ${result.message}');
    }
    return result;
  }

  Future<MediaItem?> media(String id) async {
    await activate();
    return MediaRepository().getMediaById(id);
  }

  /// A plain user edit on the row, for last-writer-wins scenarios. The
  /// narrow write, as the app's own editor uses: a whole-row update from a
  /// snapshot could write stale upload facts back over newer ones.
  Future<void> setManualElapsed(String id, int seconds) async {
    await activate();
    await MediaRepository().setManualElapsedSeconds(id, seconds);
  }

  Future<bool> isPending(String id) async {
    await activate();
    final row = await db
        .customSelect(
          "SELECT sync_status FROM sync_records "
          "WHERE entity_type = 'media' AND record_id = ?",
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row?.read<String>('sync_status') == 'pending';
  }

  Future<TileResolution> tile(String id, {bool thumbnail = false}) async {
    await activate();
    final row = (await MediaRepository().getMediaById(id))!;
    return onThisDisk(
      () => tileResolver.resolve(
        row,
        thumbnail: thumbnail,
        thumbnailTarget: const Size(200, 200),
      ),
    );
  }

  Future<TileOutcome> tileOutcome(String id, {bool thumbnail = false}) async {
    final r = await tile(id, thumbnail: thumbnail);
    if (r.data is UnavailableData) return TileOutcome.unavailable;
    return r.storeFallbackUsed ? TileOutcome.store : TileOutcome.native;
  }

  /// What `MediaItemView` does after resolving: reconcile the orphan flag
  /// and, when the verdict changed, write it (which marks the row pending).
  Future<void> checkTile(String id) async {
    await activate();
    final repo = MediaRepository();
    final row = (await repo.getMediaById(id))!;
    final r = await tile(id);
    final desired = reconciledOrphanFlag(
      currentlyOrphaned: row.isOrphaned,
      failure: r.nativeFailure,
    );
    if (desired == null) return;
    await repo.markVerified(
      id,
      isOrphaned: desired,
      verifiedAt: DateTime.now(),
    );
  }

  Future<SweepOutcome> verifyAll() async {
    await activate();
    final repo = MediaRepository();
    return onThisDisk(
      () => MediaVerificationSweep(
        repository: repo,
        verifier: MediaItemVerifier(registry: registry, repository: repo),
      ).run(),
    );
  }

  Future<void> deleteDiver(String id) async {
    await activate();
    // This device's queue: a default coordinator writes to the global cache
    // database, which the harness never points at a device.
    await DiverRepository(
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => queue,
      ),
    ).deleteDiverWithReassignment(id);
  }

  /// Simulates a gallery row linked before links recorded an origin.
  Future<void> clearOrigin(String id) async {
    await activate();
    await db.customStatement(
      'UPDATE media SET origin_device_id = NULL WHERE id = ?',
      [id],
    );
  }

  /// Simulates a gallery row linked before links recorded a cloud id.
  Future<void> clearCloudAssetId(String id) async {
    await activate();
    await db.customStatement(
      'UPDATE media SET cloud_asset_id = NULL WHERE id = ?',
      [id],
    );
  }

  /// Runs this device's one-time gallery origin backfill. The preference
  /// store is shared by both devices, so the flag is cleared first.
  Future<void> backfillGalleryOrigins() async {
    await activate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(GalleryOriginBackfill.doneFlagKey);
    await GalleryOriginBackfill(
      mediaRepository: MediaRepository(),
      reader: gallery,
      photos: gallery,
      permissionStatus: () async => gallery.permission,
      deviceId: () async => deviceId,
      prefs: prefs,
    ).run();
  }

  /// Runs this device's gallery cloud id backfill now. The preference store
  /// is shared by both devices, so the last run is cleared first, and the
  /// origin backfill it waits for is marked done: harness gallery rows
  /// record their origin at link time.
  Future<void> backfillGalleryCloudIds() async {
    await activate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(GalleryCloudIdBackfill.lastRunKey);
    await prefs.setBool(GalleryOriginBackfill.doneFlagKey, true);
    await GalleryCloudIdBackfill(
      mediaRepository: MediaRepository(),
      cloudIdentifiers: gallery,
      photos: gallery,
      permissionStatus: () async => gallery.permission,
      deviceId: () async => deviceId,
      prefs: prefs,
      assetCache: assetCache,
    ).run();
  }

  /// Simulates upload stamps that never arrived or were dropped by a merge.
  /// The content hash stays: it is what a store probe addresses the object
  /// by, and losing it is a different (unrecoverable) failure.
  Future<void> stripStoreStamps(String id) async {
    await activate();
    await db.customStatement(
      'UPDATE media SET remote_uploaded_at = NULL, '
      'remote_thumb_uploaded_at = NULL, '
      'remote_compressed_uploaded_at = NULL WHERE id = ?',
      [id],
    );
  }

  Future<void> _dispose() async {
    worker.dispose();
    await cacheDb.close();
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  }
}
