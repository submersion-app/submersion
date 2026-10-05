import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// A clip path under the platform's temp directory. The fake platform never
/// opens it; it only has to be a valid path on every OS (issue #2279).
String _tempVideoPath(String id) =>
    p.join(Directory.systemTemp.path, '$id.mp4');

MediaItem video(String id) => MediaItem(
  id: id,
  mediaType: MediaType.video,
  sourceType: MediaSourceType.localFile,
  filePath: _tempVideoPath(id),
  localPath: _tempVideoPath(id),
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
    final originalPlatform = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
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
              (ref, MediaItem arg) async => _tempVideoPath('v1'),
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

  testWidgets('in fullscreen a tap plays, reveals the controls, and they '
      'stay while paused', (tester) async {
    final platform = _FakeVideoPlatform();
    final originalPlatform = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
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
              (ref, MediaItem arg) async => _tempVideoPath('v1'),
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    // Matched on the Semantics widgets the player wraps its controls in,
    // which does not depend on how the semantics tree merges them.
    Finder semanticsWidget(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );
    final seekBar = semanticsWidget('Seek video position');
    final playPause = semanticsWidget('Play or pause video');
    final exitButton = find.byTooltip('Exit full screen');

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    expect(seekBar, findsNothing);
    expect(exitButton, findsNothing);
    // The paused clip's centre play indicator is chrome too.
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    // Tap: plays, and reveals the exit button and controls bar.
    await tester.tap(playPause);
    // PhotoView's double-tap recognizer holds a single tap until its
    // timeout, so the video only sees it after that.
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.playing, isTrue);
    expect(exitButton, findsOneWidget);
    expect(seekBar, findsOneWidget);

    // Playing: hidden again after 3 s.
    await tester.pump(const Duration(seconds: 3));
    expect(exitButton, findsNothing);
    expect(seekBar, findsNothing);

    // Tap: pauses, reveals, and stays while paused.
    await tester.tap(playPause);
    // PhotoView's double-tap recognizer holds a single tap until its
    // timeout, so the video only sees it after that.
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.playing, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(exitButton, findsOneWidget);
    expect(seekBar, findsOneWidget);
    // With no metadata panel under it, the bar sits at the bottom edge
    // rather than 160 px up.
    final viewHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getRect(seekBar).bottom, greaterThan(viewHeight - 100));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controls left up on a paused video hide on the next photo', (
    tester,
  ) async {
    final platform = _FakeVideoPlatform();
    final originalPlatform = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
    VideoPlayerPlatform.instance = platform;
    final photo = MediaItem(
      id: 'p1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      takenAt: DateTime.utc(2026, 7, 1, 11),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

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
              (ref, MediaItem arg) async => _tempVideoPath('v1'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(
              mediaList: [video('v1'), photo],
              initialMediaId: 'v1',
            ),
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

    final playPause = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Play or pause video',
    );
    final exitButton = find.byTooltip('Exit full screen');

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    // Play, then pause: the controls stay up on the paused clip.
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.playing, isFalse);
    expect(exitButton, findsOneWidget);

    // Swipe on to the photo: the 3-second hide applies again.
    await tester.fling(
      find.byType(MediaViewerPage),
      const Offset(-700, 0),
      2000,
    );
    // Let the ballistic scroll settle frame by frame (well under 3 s).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(exitButton, findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(exitButton, findsNothing);
  });
}
