import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../helpers/test_database.dart';

class _UnavailableResolver implements MediaSourceResolver {
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
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// Minimal in-memory video platform. Enough for the controller to reach its
/// initialized state so the player, its controls, and play/pause can be
/// exercised without a real decoder.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast();
  bool playing = false;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;

  @override
  Future<void> dispose(int playerId) async {}

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
}

MediaItem video(String id) => MediaItem(
  id: id,
  mediaType: MediaType.video,
  sourceType: MediaSourceType.localFile,
  filePath: '/tmp/$id.mp4',
  localPath: '/tmp/$id.mp4',
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester, {
    required Future<String?> Function() path,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.localFile: _UnavailableResolver(),
              }),
            ),
            resolvedFilePathProvider.overrideWith(
              (ref, MediaItem arg) => path(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: [video('v1')],
              initialMediaId: 'v1',
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  testWidgets('a video whose file cannot be resolved says so', (tester) async {
    await pump(tester, path: () async => null);
    expect(find.text('Video file not found'), findsOneWidget);
  });

  testWidgets('a resolve failure reports a load error, not a crash', (
    tester,
  ) async {
    await pump(tester, path: () async => throw StateError('resolver blew up'));
    expect(find.text('Failed to load video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resolvable video reaches the player and its controls', (
    tester,
  ) async {
    final platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.localFile: _UnavailableResolver(),
              }),
            ),
            resolvedFilePathProvider.overrideWith(
              (ref, MediaItem arg) async => '/tmp/v1.mp4',
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: [video('v1')],
              initialMediaId: 'v1',
            ),
          ),
        ),
      );
      // Let initializeVideo reach controller.initialize(), then answer it.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    // Neither error message: the initialized branch rendered instead.
    expect(find.text('Video file not found'), findsNothing);
    expect(find.text('Failed to load video'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
