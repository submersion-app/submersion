import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/in_memory_media_object_store.dart';

/// A browser reads the media store and never writes it (issue #4121): its
/// runtime serves what the store holds from page memory, with no worker to
/// drain uploads or deletes, no sweep that uploads, and no disk cache. No
/// path provider, cache directory or cache database is set up here, since a
/// page has none of them.
void main() {
  final bytes = List<int>.generate(256, (i) => (i * 3) % 251);
  final hash = sha256.convert(bytes).toString();
  late SharedPreferences prefs;
  late InMemoryMediaObjectStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      MediaStoreAttachState.storeIdKey: 'store-1',
    });
    prefs = await SharedPreferences.getInstance();
    store = InMemoryMediaObjectStore();
    store.objects[StoreKeys.thumbKey(hash)] = bytes;
  });

  ProviderContainer browser() {
    final scope = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        mediaStoreAttachStateProvider.overrideWithValue(
          MediaStoreAttachState(prefs: prefs),
        ),
        attachedMediaObjectStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(scope.dispose);
    return scope;
  }

  final item = MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    localPath: 'elsewhere/reef.jpg',
    originalFilename: 'reef.jpg',
    contentHash: hash,
    remoteThumbUploadedAt: DateTime(2026),
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('a browser runtime serves the store from memory, with no worker '
      'and no disk cache', () async {
    final runtime = await browser().read(mediaStoreRuntimeProvider.future);

    expect(runtime, isNotNull);
    expect(runtime!.storeId, 'store-1');
    expect(runtime.worker, isNull);
    expect(runtime.cache, isNull);
    final served = await runtime.resolver.tryResolveRemote(
      item,
      thumbnail: true,
    );
    expect((served! as BytesData).bytes, bytes);
  });

  test("a browser's probe resolver serves from memory too", () async {
    final probe = await browser().read(mediaStoreProbeResolverProvider.future);

    final served = await probe!.tryResolveProbed(
      item.copyWith(remoteThumbUploadedAt: null),
      thumbnail: true,
    );
    expect(served, isA<BytesData>());
  });
}
