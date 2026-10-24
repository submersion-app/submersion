import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
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
}

/// A platform with no player, as on Windows before video_player_win (#3548):
/// creation throws the platform interface's own UnimplementedError. The
/// controller then never completes its creation, so its dispose() waits
/// forever.
class _UncreatableVideoPlatform extends _FakeVideoPlatform {
  @override
  Future<int?> create(DataSource dataSource) =>
      throw UnimplementedError('create() has not been implemented.');

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      throw UnimplementedError('create() has not been implemented.');
}

/// A platform whose native release fails, so VideoPlayerController.dispose()
/// throws.
class _UnreleasableVideoPlatform extends _FakeVideoPlatform {
  @override
  Future<void> dispose(int playerId) async {
    disposed++;
    throw PlatformException(code: 'VideoError', message: 'release blew up');
  }
}

/// Installs [platform] as the player for this test, restoring the previous
/// one when it ends: CI runs many test files in one isolate (#2500).
void _usePlatform(VideoPlayerPlatform platform) {
  final original = VideoPlayerPlatform.instance;
  addTearDown(() => VideoPlayerPlatform.instance = original);
  VideoPlayerPlatform.instance = platform;
}

/// Every log entry written from now until the test ends.
List<LogEntry> _captureLogs() {
  final logged = <LogEntry>[];
  final subscription = LoggerService.logStream.listen(logged.add);
  addTearDown(subscription.cancel);
  return logged;
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

  testWidgets('a player that cannot be created reports and logs the failure '
      'instead of spinning', (tester) async {
    _usePlatform(_UncreatableVideoPlatform());
    final logged = _captureLogs();

    await pump(tester, path: () async => _tempVideoPath('v1'));

    expect(find.text('Failed to load video'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      logged.where(
        (e) =>
            e.category == LogCategory.media &&
            e.message.contains('create() has not been implemented'),
      ),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a video that fails after its player was created reports the '
      'failure and still releases the player', (tester) async {
    final platform = _FakeVideoPlatform();
    _usePlatform(platform);

    // pump() leaves initialize() waiting on the platform's events.
    await pump(tester, path: () async => _tempVideoPath('v1'));
    await tester.runAsync(() async {
      platform.failInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(find.text('Failed to load video'), findsOneWidget);
    expect(platform.created, 1);
    // The native decoder is not left behind for the process lifetime.
    expect(platform.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load that finishes after the viewer closed releases its '
      'player', (tester) async {
    final platform = _FakeVideoPlatform();
    _usePlatform(platform);

    // pump() leaves initialize() waiting on the platform's events.
    await pump(tester, path: () async => _tempVideoPath('v1'));
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      platform.completeInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    expect(platform.created, 1);
    expect(platform.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a release that fails is logged, not left unhandled', (
    tester,
  ) async {
    final platform = _UnreleasableVideoPlatform();
    _usePlatform(platform);
    final logged = _captureLogs();

    await pump(tester, path: () async => _tempVideoPath('v1'));
    await tester.runAsync(() async {
      platform.failInitialization();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });

    expect(find.text('Failed to load video'), findsOneWidget);
    expect(platform.disposed, 1);
    expect(
      logged.where(
        (e) =>
            e.category == LogCategory.media &&
            e.message.contains('release failed') &&
            e.message.contains('release blew up'),
      ),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resolvable video reaches the player and its controls', (
    tester,
  ) async {
    final platform = _FakeVideoPlatform();
    _usePlatform(platform);

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
    _usePlatform(platform);

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
    _usePlatform(platform);
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

  // Issue #3298: the pager now keeps each neighbour built so it can load
  // ahead of a swipe. A video swiped away therefore stays mounted one page
  // off screen, and has to stop playing rather than carry on unseen.
  testWidgets('a playing video pauses when swiped away', (tester) async {
    final platform = _FakeVideoPlatform();
    _usePlatform(platform);
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

    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Play or pause video',
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(platform.playing, isTrue);

    await tester.fling(
      find.byType(MediaViewerPage),
      const Offset(-700, 0),
      2000,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The release finishes on the real clock: VideoPlayerController.dispose
    // awaits cancelling an event subscription made inside runAsync.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    // No page-indicator check: the chrome hides while a clip plays. A swipe
    // that did not land would leave the clip playing and fail here anyway.
    expect(platform.playing, isFalse);
    // Released, not merely paused: a kept neighbour must not hold a native
    // decoder while off screen (#1175).
    expect(platform.disposed, platform.created);

    // Nor may it keep keyboard focus: the space bar would start it again
    // off screen.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(platform.playing, isFalse);
  });

  // A neighbour video is built ahead, but its native player is not: only the
  // page on screen holds a decoder, as before neighbours stayed built.
  testWidgets('a neighbouring video creates no player until shown', (
    tester,
  ) async {
    final platform = _FakeVideoPlatform();
    _usePlatform(platform);
    final photo = MediaItem(
      id: 'p1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      takenAt: DateTime.utc(2026, 7, 1, 9),
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
              mediaList: [photo, video('v1')],
              initialMediaId: 'p1',
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await tester.pump();
    });

    expect(platform.created, 0);
    // Nor an endless spinner: an indeterminate indicator one page off screen
    // ticks every frame, so the viewer would never go idle.
    expect(
      find.byType(CircularProgressIndicator, skipOffstage: false),
      findsNothing,
    );

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Next media'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    expect(platform.created, 1);
  });
}
