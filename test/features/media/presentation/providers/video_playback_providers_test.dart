import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_streaming.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_stream_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_playback_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

final _video = MediaItem(
  id: 'm1',
  mediaType: MediaType.video,
  takenAt: DateTime.utc(2026, 6, 9),
  createdAt: DateTime.utc(2026, 6, 9),
  updatedAt: DateTime.utc(2026, 6, 9),
  originalFilename: 'clip.mp4',
  contentHash:
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
  remoteUploadedAt: DateTime.utc(2026, 6, 9),
);

class _LinkStore implements MediaObjectStore, DirectLinkStore {
  /// Keys a HEAD finds; empty unless a test fills it.
  final Set<String> held = {};

  @override
  Future<StoreObjectInfo?> head(String key) async => held.contains(key)
      ? StoreObjectInfo(key: key, lastModified: DateTime.utc(2026, 7, 1))
      : null;

  @override
  Future<DirectLink> directLink(String key, {bool fresh = false}) async =>
      DirectLink(
        url: Uri.parse('https://s3.test/$key'),
        expiresAt: DateTime.utc(2026, 6, 9, 18),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerWith(List overrides) {
    final container = ProviderContainer(overrides: [...overrides]);
    addTearDown(container.dispose);
    return container;
  }

  test('outside a browser a found file plays from its path', () async {
    final container = containerWith([
      resolvedFilePathProvider(_video).overrideWith((ref) async => '/v.mp4'),
    ]);
    final plan = await container.read(videoPlaybackProvider(_video).future);
    expect((plan as FilePlayback).path, '/v.mp4');
  });

  test('outside a browser no file is not found', () async {
    final container = containerWith([
      resolvedFilePathProvider(_video).overrideWith((ref) async => null),
    ]);
    final plan = await container.read(videoPlaybackProvider(_video).future);
    expect((plan as NoPlayback).reason, NoPlaybackReason.notFound);
  });

  test(
    'in a browser a row with no stamps plays what the store holds',
    () async {
      // Its upload facts have not reached this browser yet.
      final unstamped = _video.copyWith(remoteUploadedAt: null);
      final store = _LinkStore()
        ..held.add(StoreKeys.objectKey(_video.contentHash!, extension: 'mp4'));
      final container = containerWith([
        deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        mediaStreamRelayProvider.overrideWith((ref) async => null),
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => MediaStoreRuntime(
            storeId: 's1',
            store: store,
            resolver: MediaStoreResolver.inMemory(store: store),
          ),
        ),
      ]);
      final plan = await container.read(
        videoPlaybackProvider(unstamped).future,
      );
      final candidates = (plan as StreamPlayback).candidates;
      expect(candidates.map((c) => c.tier), [ServedTier.original]);
    },
  );

  test('in a browser the store streams it', () async {
    final store = _LinkStore();
    final container = containerWith([
      deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
      mediaStreamRelayProvider.overrideWith((ref) async => null),
      mediaStoreRuntimeProvider.overrideWith(
        (ref) async => MediaStoreRuntime(
          storeId: 's1',
          store: store,
          resolver: MediaStoreResolver.inMemory(store: store),
        ),
      ),
    ]);
    final plan = await container.read(videoPlaybackProvider(_video).future);
    final url = await (plan as StreamPlayback).candidates.single.open();
    expect(url.host, 's3.test');
  });

  test('in a browser with no store attached it is not found', () async {
    final container = containerWith([
      deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
      mediaStreamRelayProvider.overrideWith((ref) async => null),
      mediaStoreRuntimeProvider.overrideWith((ref) async => null),
    ]);
    final plan = await container.read(videoPlaybackProvider(_video).future);
    expect((plan as NoPlayback).reason, NoPlaybackReason.notFound);
  });

  test(
    'in a browser an S3 video does not wait for the stream worker',
    () async {
      // A worker that never starts (an uncontrolled page) must not hold up
      // stores that never use it.
      final store = _LinkStore();
      final container = containerWith([
        deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        mediaStreamRelayProvider.overrideWith(
          (ref) => Completer<MediaStreamRelay?>().future,
        ),
        mediaStoreRuntimeProvider.overrideWith(
          (ref) async => MediaStoreRuntime(
            storeId: 's1',
            store: store,
            resolver: MediaStoreResolver.inMemory(store: store),
          ),
        ),
      ]);
      final plan = await container
          .read(videoPlaybackProvider(_video).future)
          .timeout(const Duration(seconds: 5));
      expect(plan, isA<StreamPlayback>());
    },
  );
}
