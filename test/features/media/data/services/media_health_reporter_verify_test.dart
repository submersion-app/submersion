import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_health_reporter.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/diagnostic_probe.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';

/// A report must not change what it observes, and must not phone home.
///
/// Two source types break both rules through `verify()`: a gallery verify
/// runs the resolution service, which rewrites the local asset cache and so
/// pushes the next automatic search a week out, and a network or manifest
/// verify fetches a byte range from the host, once per row. Those rows are
/// reported from stored state instead.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late _SpyResolver spy;
  late MediaHealthReporter reporter;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    spy = _SpyResolver();
    reporter = MediaHealthReporter(
      mediaRepository: MediaRepository(),
      syncRepository: SyncRepository(),
      assetCache: LocalAssetCacheRepository(),
      queue: MediaTransferQueueRepository(),
      registry: MediaSourceResolverRegistry({
        for (final t in MediaSourceType.values) t: spy,
      }),
      attachState: MediaStoreAttachState(),
      store: () async => null,
      localDeviceId: () async => 'dev-1',
      localDeviceName: () async => 'This device',
      deviceName: (_) => null,
    );
  });

  tearDown(() async {
    LocalCacheDatabaseService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await cacheDb.close();
    await db.close();
  });

  MediaItem row(MediaSourceType type) => MediaItem(
    id: 'm-${type.name}',
    mediaType: MediaType.photo,
    sourceType: type,
    localPath: '/nowhere/reef.jpg',
    url: 'https://example.com/a.jpg',
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  Future<String> verdictFor(MediaSourceType type) async =>
      (await reporter.forItem(row(type))).rows.single.resolverVerdict;

  const reportedFromStoredState = {
    MediaSourceType.platformGallery: 'notProbed: gallery',
    MediaSourceType.networkUrl: 'notProbed: network',
    MediaSourceType.manifestEntry: 'notProbed: network',
    MediaSourceType.mediaStore: 'mediaStore',
  };

  for (final entry in reportedFromStoredState.entries) {
    test('${entry.key.name} is never verified live', () async {
      expect(await verdictFor(entry.key), entry.value);
      expect(
        spy.verified,
        isEmpty,
        reason: 'verify() must not run for ${entry.key.name}',
      );
    });
  }

  for (final type in [
    MediaSourceType.localFile,
    MediaSourceType.serviceConnector,
    MediaSourceType.signature,
  ]) {
    test('${type.name} still gets a live verdict', () async {
      expect(await verdictFor(type), VerifyResult.available.name);
      expect(spy.verified, [type]);
    });
  }

  group('a resolver that offers a read-free probe', () {
    late _ProbeResolver probeResolver;

    MediaHealthReporter reporterWith(_ProbeResolver r) => MediaHealthReporter(
      mediaRepository: MediaRepository(),
      syncRepository: SyncRepository(),
      assetCache: LocalAssetCacheRepository(),
      queue: MediaTransferQueueRepository(),
      registry: MediaSourceResolverRegistry({
        for (final t in MediaSourceType.values) t: r,
      }),
      attachState: MediaStoreAttachState(),
      store: () async => null,
      localDeviceId: () async => 'dev-1',
      localDeviceName: () async => 'This device',
      deviceName: (_) => null,
    );

    setUp(() => probeResolver = _ProbeResolver());

    test('is probed, never verified', () async {
      final report = await reporterWith(
        probeResolver,
      ).forItem(row(MediaSourceType.localFile));

      expect(report.rows.single.resolverVerdict, VerifyResult.available.name);
      expect(probeResolver.probed, 1);
      expect(
        probeResolver.verified,
        0,
        reason: 'verify reads the bytes on the bookmark path',
      );
    });

    test('a probe that cannot answer reports notProbed', () async {
      probeResolver.answer = null;

      final report = await reporterWith(
        probeResolver,
      ).forItem(row(MediaSourceType.localFile));

      expect(report.rows.single.resolverVerdict, 'notProbed: needs a read');
      expect(probeResolver.verified, 0, reason: 'never fall back to a read');
    });
  });

  test('a store that cannot be built still yields a report', () async {
    // Its credentials no longer parse, so building it throws. Every other
    // field is exactly what that misconfiguration needs.
    final reporter = MediaHealthReporter(
      mediaRepository: MediaRepository(),
      syncRepository: SyncRepository(),
      assetCache: LocalAssetCacheRepository(),
      queue: MediaTransferQueueRepository(),
      registry: MediaSourceResolverRegistry({
        for (final t in MediaSourceType.values) t: spy,
      }),
      attachState: MediaStoreAttachState(),
      store: () async => throw StateError('bad credentials'),
      localDeviceId: () async => 'dev-1',
      localDeviceName: () async => 'This device',
      deviceName: (_) => null,
    );

    final report = await reporter.forItem(row(MediaSourceType.localFile));

    expect(report.markerStoreId, isNull);
    expect(report.rows.single.mediaId, 'm-localFile');
  });

  group('cache expiry is read from the entry in hand', () {
    Future<void> seed({
      required String method,
      String? assetId,
      required int attempts,
      required DateTime resolvedAt,
    }) => LocalAssetCacheRepository()
        .cacheResolution(
          mediaId: 'm-localFile',
          localAssetId: assetId,
          method: method,
        )
        .then(
          (_) => LocalCacheDatabaseService.instance.database.customStatement(
            'UPDATE local_asset_cache SET attempt_count = ?, resolved_at = ? '
            'WHERE media_id = ?',
            [attempts, resolvedAt.millisecondsSinceEpoch, 'm-localFile'],
          ),
        );

    Future<bool?> expiredFor(MediaSourceType type) async =>
        (await reporter.forItem(row(type))).rows.single.cacheExpired;

    test('a resolved entry never expires', () async {
      await seed(
        method: 'original_id',
        assetId: 'PH-1',
        attempts: 9,
        resolvedAt: DateTime(2020),
      );

      expect(await expiredFor(MediaSourceType.localFile), isFalse);
    });

    test('an unresolved entry past its backoff is expired', () async {
      await seed(
        method: 'unresolved',
        attempts: 0,
        resolvedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      expect(await expiredFor(MediaSourceType.localFile), isTrue);
    });

    test('an unresolved entry inside its backoff is fresh', () async {
      await seed(
        method: 'unresolved',
        attempts: 0,
        resolvedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(await expiredFor(MediaSourceType.localFile), isFalse);
    });
  });

  test('a library report verifies only the local-read types', () async {
    for (final type in MediaSourceType.values) {
      await verdictFor(type);
    }

    expect(spy.verified, [
      MediaSourceType.localFile,
      MediaSourceType.serviceConnector,
      MediaSourceType.signature,
    ]);
  });
}

/// Records every type it is asked to verify. A real resolver would reach the
/// gallery or the network here, which is the point.
class _SpyResolver implements MediaSourceResolver {
  final verified = <MediaSourceType>[];

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    verified.add(item.sourceType);
    return VerifyResult.available;
  }

  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      throw StateError('a report must never take the bytes path');

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => throw StateError('a report must never take the bytes path');

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
}

/// Answers the read-free probe and records whether anything fell back to
/// the byte-reading verify.
class _ProbeResolver implements MediaSourceResolver, DiagnosticProbe {
  VerifyResult? answer = VerifyResult.available;
  int probed = 0;
  int verified = 0;

  @override
  Future<VerifyResult?> probe(MediaItem item) async {
    probed++;
    return answer;
  }

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    verified++;
    return VerifyResult.available;
  }

  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      throw StateError('a report must never take the bytes path');

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => throw StateError('a report must never take the bytes path');

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
}
