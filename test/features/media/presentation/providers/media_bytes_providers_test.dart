import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';

/// A document attachment is the case that broke: it carries no
/// `platformAssetId`, so the gallery-asset provider the document viewer used
/// to call could never resolve it and every PDF opened to "not available on
/// this device" (issue #1019). These tests pin the replacement to the source
/// the row actually points at.
void main() {
  late FakeLocalFileResolver resolver;

  setUp(() => resolver = FakeLocalFileResolver());

  MediaItem pdf({
    String? contentHash,
    DateTime? remoteUploadedAt,
    MediaSourceType sourceType = MediaSourceType.localFile,
  }) => MediaItem(
    id: 'doc-1',
    siteId: 'site-1',
    mediaType: MediaType.document,
    sourceType: sourceType,
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
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('serves the bytes a localFile document resolves to', () async {
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    resolver.data = BytesData(bytes: bytes);

    final result = await container().read(mediaBytesProvider(pdf()).future);

    expect(result.isAvailable, isTrue);
    expect(result.bytes, equals(bytes));
  });

  test('reads a resolved file off disk', () async {
    final dir = await Directory.systemTemp.createTemp('media_bytes');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/reef-map.pdf')
      ..writeAsBytesSync([1, 2, 3, 4]);
    resolver.data = FileData(file: file);

    final result = await container().read(mediaBytesProvider(pdf()).future);

    expect(result.bytes, equals(Uint8List.fromList([1, 2, 3, 4])));
  });

  test('reports unavailable when the source cannot resolve and no store '
      'is attached', () async {
    resolver.data = const UnavailableData(kind: UnavailableKind.notFound);

    final result = await container().read(mediaBytesProvider(pdf()).future);

    expect(result.isUnavailable, isTrue);
    expect(result.bytes, isNull);
  });

  test('a NetworkData source is not bytes and reads unavailable', () async {
    resolver.data = NetworkData(url: Uri.parse('https://example.com/a.pdf'));

    final result = await container().read(mediaBytesProvider(pdf()).future);

    expect(result.isUnavailable, isTrue);
  });

  // A row whose source type has no registered resolver is a programmer
  // error the registry signals by throwing. It must not escape into the
  // viewer as a red error screen: the honest answer for one unopenable
  // attachment is the unavailable placeholder.
  test('an unregistered source type reads unavailable rather than '
      'throwing', () async {
    final result = await container().read(
      mediaBytesProvider(pdf(sourceType: MediaSourceType.signature)).future,
    );

    expect(result.isUnavailable, isTrue);
  });

  // The resolver checks the file exists before handing it back, so a read
  // that still fails means it went away in between (an ejected volume, a
  // cache sweep). That is a placeholder, not an exception thrown out of a
  // provider the viewer is watching.
  test('a resolved file that has since vanished reads unavailable', () async {
    final dir = await Directory.systemTemp.createTemp('media_bytes_gone');
    addTearDown(() => dir.delete(recursive: true));
    resolver.data = FileData(file: File('${dir.path}/never-written.pdf'));

    final result = await container().read(mediaBytesProvider(pdf()).future);

    expect(result.isUnavailable, isTrue);
  });

  // Building the store runtime reads credentials out of the keychain, which
  // can fail for reasons that have nothing to do with this document.
  test('a store runtime that fails to build leaves the item '
      'unavailable', () async {
    resolver.data = const UnavailableData(kind: UnavailableKind.notFound);

    final c = ProviderContainer(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({MediaSourceType.localFile: resolver}),
        ),
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => throw StateError('keychain unavailable'),
        ),
      ],
    );
    addTearDown(c.dispose);

    final result = await c.read(mediaBytesProvider(pdf()).future);

    expect(result.isUnavailable, isTrue);
  });

  test('falls back to the media store when the device holds no local '
      'copy', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('media_bytes_store');
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
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

    final result = await container(runtime: runtime).read(
      mediaBytesProvider(
        pdf(contentHash: digest.hash, remoteUploadedAt: DateTime(2026, 8, 12)),
      ).future,
    );

    expect(result.isAvailable, isTrue);
    expect(result.bytes, equals(Uint8List.fromList(bytes)));
  });
}
