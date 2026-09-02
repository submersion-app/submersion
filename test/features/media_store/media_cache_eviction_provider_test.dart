import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  late Directory support;
  late LocalCacheDatabase db;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('eviction_provider_test');
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

  /// Indexes a cache entry without writing a file. Eviction sums sizeBytes
  /// from the index and tolerates a missing file, so this is enough to put the
  /// pool over its cap without producing gigabytes on disk.
  Future<void> indexEntry(String hash, int sizeBytes, int accessedAt) {
    return db
        .into(db.mediaCacheEntries)
        .insert(
          MediaCacheEntriesCompanion.insert(
            contentHash: hash,
            kind: 'original',
            relativePath: 'originals/${hash.substring(0, 2)}/$hash',
            sizeBytes: sizeBytes,
            lastAccessedAt: accessedAt,
            createdAt: accessedAt,
          ),
        );
  }

  Future<int> originalsBytes() async {
    final rows = await (db.select(
      db.mediaCacheEntries,
    )..where((t) => t.kind.equals('original'))).get();
    return rows.fold<int>(0, (sum, row) => sum + row.sizeBytes);
  }

  test('the provider brings an over-cap pool back under budget', () async {
    // The production originals cap is 2 GiB. Three 1 GiB entries put the pool
    // over it without any file ever existing on disk.
    const oneGiB = 1024 * 1024 * 1024;
    await indexEntry('aa${'1' * 62}', oneGiB, 1000);
    await indexEntry('bb${'2' * 62}', oneGiB, 2000);
    await indexEntry('cc${'3' * 62}', oneGiB, 3000);
    expect(await originalsBytes(), 3 * oneGiB);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(mediaCacheEvictionProvider.future);

    expect(await originalsBytes(), lessThanOrEqualTo(2 * oneGiB));
    // Oldest lastAccessedAt goes first.
    final remaining = (await db.select(db.mediaCacheEntries).get())
        .map((r) => r.contentHash)
        .toList();
    expect(remaining, isNot(contains('aa${'1' * 62}')));
  });

  test('a pool already under cap is left alone', () async {
    await indexEntry('dd${'4' * 62}', 1024, 1000);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(mediaCacheEvictionProvider.future);

    expect(await originalsBytes(), 1024);
  });
}
