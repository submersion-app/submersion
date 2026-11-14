import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared by the media viewer's video tests: a resolver that resolves
/// nothing, an in-memory video platform, and the clips they open.

class UnavailableVideoResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// Minimal in-memory video platform. Enough for the controller to reach its
/// initialized state so the player, its controls, and play/pause can be
/// exercised without a real decoder.
class FakeVideoPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast();
  bool playing = false;

  /// Native players created and released, so a test can tell how many
  /// decoders the viewer holds.
  int created = 0;
  int disposed = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    created++;
    return 1;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created++;
    return 1;
  }

  /// A released player stops, as the real platforms' players do.
  @override
  Future<void> dispose(int playerId) async {
    disposed++;
    playing = false;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => playing = true;

  @override
  Future<void> pause(int playerId) async => playing = false;

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  /// Announces a ready 640x360 clip; VideoPlayerController.initialize()
  /// completes only once this lands.
  void completeInitialization() {
    _events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(640, 360),
        rotationCorrection: 0,
      ),
    );
  }

  /// Reports a clip the decoder cannot open, after its player was created;
  /// VideoPlayerController.initialize() then throws.
  void failInitialization() {
    _events.addError(
      PlatformException(code: 'VideoError', message: 'Unsupported codec'),
    );
  }

  /// Reports a play state from the native player, as the platforms do on
  /// their own schedule (after a seek, or when a clip ends).
  void reportPlaying(bool isPlaying) {
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: isPlaying,
      ),
    );
  }
}

/// Installs [platform] as the player for this test, restoring the previous
/// one when it ends: CI runs many test files in one isolate (#2500).
void useVideoPlatform(VideoPlayerPlatform platform) {
  final original = VideoPlayerPlatform.instance;
  addTearDown(() => VideoPlayerPlatform.instance = original);
  VideoPlayerPlatform.instance = platform;
}

/// A clip path under the platform's temp directory. The fake platform never
/// opens it; it only has to be a valid path on every OS (issue #2279).
String tempVideoPath(String id) => p.join(Directory.systemTemp.path, '$id.mp4');

MediaItem video(String id) => MediaItem(
  id: id,
  mediaType: MediaType.video,
  sourceType: MediaSourceType.localFile,
  filePath: tempVideoPath(id),
  localPath: tempVideoPath(id),
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

/// Opens the viewer on one clip ('v1') played by a fresh [FakeVideoPlatform],
/// initialized and ready, and returns the platform.
Future<FakeVideoPlatform> pumpVideoViewer(
  WidgetTester tester,
  SharedPreferences prefs,
) async {
  final platform = FakeVideoPlatform();
  useVideoPlatform(platform);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaSourceResolverRegistryProvider.overrideWithValue(
            MediaSourceResolverRegistry({
              MediaSourceType.localFile: UnavailableVideoResolver(),
            }),
          ),
          resolvedFilePathProvider.overrideWith(
            (ref, MediaItem arg) async => tempVideoPath('v1'),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaViewerPage(mediaList: [video('v1')], initialMediaId: 'v1'),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    platform.completeInitialization();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  });
  return platform;
}
