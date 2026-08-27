import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';

void main() {
  late FakeLocalFileResolver resolver;
  late MediaServingRecorder recorder;

  setUp(() {
    resolver = FakeLocalFileResolver();
    recorder = MediaServingRecorder();
  });

  MediaItem doc({String? contentHash, DateTime? remoteUploadedAt}) => MediaItem(
    id: 'doc-1',
    siteId: 'site-1',
    mediaType: MediaType.document,
    sourceType: MediaSourceType.localFile,
    originalFilename: 'reef-map.pdf',
    takenAt: DateTime(2026, 8, 12),
    createdAt: DateTime(2026, 8, 12),
    updatedAt: DateTime(2026, 8, 12),
    contentHash: contentHash,
    remoteUploadedAt: remoteUploadedAt,
  );

  ProviderContainer container({MediaStoreRuntime? runtime}) {
    final c = ProviderContainer(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({MediaSourceType.localFile: resolver}),
        ),
        mediaStoreRuntimeProvider.overrideWith((ref) async => runtime),
        mediaServingRecorderProvider.overrideWithValue(recorder),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a native success is recorded with no store fallback', () async {
    resolver.data = BytesData(
      bytes: Uint8List.fromList([37, 80, 68, 70]),
      servedFrom: ServedFrom.localDisk,
    );

    await container().read(mediaBytesProvider(doc()).future);

    final obs = recorder.lastFor('doc-1', thumbnail: false)!;
    expect(obs.servedFrom, ServedFrom.localDisk);
    expect(obs.servedTier, ServedTier.original);
    expect(obs.storeFallbackUsed, isFalse);
    expect(obs.failure, isNull);
  });

  test('a store fallback success is recorded as such', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('mbp_prov_store');
    addTearDown(() async {
      await db.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final store = InMemoryMediaObjectStore();
    final cache = MediaCacheStore(database: db, root: root);

    final bytes = List<int>.generate(2048, (i) => (i * 7) % 251);
    final seed = File('${root.path}/seed.pdf')..writeAsBytesSync(bytes);
    final digest = await sha256OfFile(seed);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'pdf')] = bytes;

    resolver.data = const UnavailableData(kind: UnavailableKind.notFound);

    final runtime = MediaStoreRuntime(
      storeId: 's1',
      store: store,
      cache: cache,
      resolver: MediaStoreResolver(store: store, cache: cache),
    );

    await container(runtime: runtime).read(
      mediaBytesProvider(
        doc(contentHash: digest.hash, remoteUploadedAt: DateTime(2026, 8, 12)),
      ).future,
    );

    final obs = recorder.lastFor('doc-1', thumbnail: false)!;
    expect(obs.servedFrom, ServedFrom.storeNetwork);
    expect(obs.servedTier, ServedTier.original);
    expect(obs.storeFallbackUsed, isTrue);
    expect(obs.failure, isNull);
  });

  test('a total failure is recorded with the native failure kind', () async {
    resolver.data = const UnavailableData(kind: UnavailableKind.volumeOffline);

    await container().read(mediaBytesProvider(doc()).future);

    final obs = recorder.lastFor('doc-1', thumbnail: false)!;
    expect(obs.servedFrom, isNull);
    expect(obs.failure, UnavailableKind.volumeOffline);
    // The store WAS asked and could not help. This records that the fallback
    // ran, not that it succeeded.
    expect(obs.storeFallbackUsed, isTrue);
  });

  test('a NetworkData native resolution records as notFound', () async {
    // This provider deliberately never fetches NetworkData, so such a row
    // yields no bytes without ever being an UnavailableData. For a byte
    // consumer that is indistinguishable from an absent source.
    resolver.data = NetworkData(url: Uri.parse('https://example.com/a.pdf'));

    await container().read(mediaBytesProvider(doc()).future);

    final obs = recorder.lastFor('doc-1', thumbnail: false)!;
    expect(obs.servedFrom, isNull);
    expect(obs.failure, UnavailableKind.notFound);
  });
}
