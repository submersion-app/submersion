import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// Exercises the real `storageInventoryProvider` rather than an injected one.
///
/// Every other test of the inventory constructs it with fakes, which is the
/// right way to test the measurement strategies but leaves the production
/// wiring, the part that decides which directory and which database each
/// category actually reads, unexercised.
void main() {
  late Directory support;
  late LocalCacheDatabase db;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('storage_wiring_test');
    PathProviderPlatform.instance = _FakePathProvider(support.path);
    resetMediaCacheRootForTesting();
    LocalCacheDatabaseService.instance.resetForTesting();
    await LocalCacheDatabaseService.instance.initialize();
    db = LocalCacheDatabaseService.instance.database;
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    resetMediaCacheRootForTesting();
    if (support.existsSync()) await support.delete(recursive: true);
  });

  test('the media cache rows read the real index', () async {
    await db
        .into(db.mediaCacheEntries)
        .insert(
          MediaCacheEntriesCompanion.insert(
            contentHash: 'aa${'1' * 62}',
            kind: 'original',
            relativePath: 'originals/aa/aa${'1' * 62}',
            sizeBytes: 4096,
            lastAccessedAt: 1000,
            createdAt: 1000,
          ),
        );

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final bytes = await container.read(
      storageCategorySizeProvider(StorageCategoryId.mediaCacheOriginals).future,
    );

    expect(bytes, 4096);
  });

  test(
    'an empty pool measures zero rather than reporting unavailable',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bytes = await container.read(
        storageCategorySizeProvider(StorageCategoryId.mediaCacheThumbs).future,
      );

      expect(bytes, 0);
    },
  );
}
