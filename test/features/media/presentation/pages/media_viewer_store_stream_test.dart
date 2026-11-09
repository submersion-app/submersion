import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/video_playback_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../helpers/test_database.dart';

/// Initialises every player it creates, and remembers each one's source.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  final List<String> sources = [];
  final Map<int, StreamController<VideoEvent>> _events = {};

  /// Reports a playback error on player [id] after it started.
  void failAfterStart(int id) => _events[id]!.addError(
    PlatformException(code: 'VideoError', message: 'link expired'),
  );

  Future<int?> _create(DataSource source) async {
    sources.add(source.uri ?? source.asset ?? '');
    final id = sources.length;
    late final StreamController<VideoEvent> events;
    events = _events[id] = StreamController<VideoEvent>.broadcast(
      onListen: () => scheduleMicrotask(
        () => events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 30),
            size: const Size(640, 360),
            rotationCorrection: 0,
          ),
        ),
      ),
    );
    return id;
  }

  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) => _create(dataSource);
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      _create(options.dataSource);
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
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
  Widget buildView(int playerId) =>
      SizedBox.expand(key: ValueKey('player-$playerId'));
}

final _video = MediaItem(
  id: 'v1',
  mediaType: MediaType.video,
  takenAt: DateTime.utc(2026, 7, 1, 10),
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
  originalFilename: 'clip.mp4',
);

void main() {
  late SharedPreferences prefs;
  late _FakeVideoPlatform platform;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final original = VideoPlayerPlatform.instance;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester,
    VideoPlayback playback, {
    bool browser = false,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            if (browser)
              deviceCapabilitiesProvider.overrideWithValue(
                DeviceCapabilities.web,
              ),
            videoPlaybackProvider.overrideWith(
              (ref, MediaItem arg) async => playback,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaViewerPage(mediaList: [_video], initialMediaId: 'v1'),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
  }

  testWidgets('a streamed video plays from the link the store gives', (
    tester,
  ) async {
    await pump(
      tester,
      StreamPlayback([
        StreamCandidate(
          tier: ServedTier.original,
          open: () async => Uri.parse('https://store.test/clip.mp4?sig=1'),
          close: (_) {},
        ),
      ]),
    );
    expect(platform.sources, ['https://store.test/clip.mp4?sig=1']);
    expect(find.byKey(const ValueKey('player-1')), findsOneWidget);
    expect(find.text('Video file not found'), findsNothing);
  });

  testWidgets('a browser without a stream worker says it needs a normal '
      'window', (tester) async {
    await pump(tester, const NoPlayback(NoPlaybackReason.needsNormalWindow));
    expect(
      find.text(
        'Playing this video needs a normal browser window. Private windows '
        'cannot stream from Google Drive or WebDAV.',
      ),
      findsOneWidget,
    );
    expect(platform.sources, isEmpty);
  });

  testWidgets('nothing to play still says the file was not found', (
    tester,
  ) async {
    await pump(tester, const NoPlayback(NoPlaybackReason.notFound));
    expect(find.text('Video file not found'), findsOneWidget);
  });

  // Issue #4162: Pick white and the colour track read frames from a file
  // through the transcode engine, which a browser has neither of. The
  // browser viewer is read-only, so neither is offered there.
  testWidgets('in a browser a streamed video offers no colour tools', (
    tester,
  ) async {
    await pump(
      tester,
      StreamPlayback([
        StreamCandidate(
          tier: ServedTier.original,
          open: () async => Uri.parse('https://store.test/clip.mp4?sig=1'),
          close: (_) {},
        ),
      ]),
      browser: true,
    );
    expect(find.byKey(const ValueKey('player-1')), findsOneWidget);
    expect(find.byTooltip('Adjust color'), findsNothing);
    expect(find.text('Pick white'), findsNothing);
  });

  StreamPlayback freshLinks() {
    var opened = 0;
    return StreamPlayback([
      StreamCandidate(
        tier: ServedTier.original,
        open: () async =>
            Uri.parse('https://store.test/clip.mp4?sig=${++opened}'),
        close: (_) {},
      ),
    ]);
  }

  testWidgets(
    'a streamed video whose link fails is reopened from a fresh one',
    (tester) async {
      await pump(tester, freshLinks());
      await tester.runAsync(() async {
        platform.failAfterStart(1);
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      expect(platform.sources, [
        'https://store.test/clip.mp4?sig=1',
        'https://store.test/clip.mp4?sig=2',
      ]);
      expect(find.byKey(const ValueKey('player-2')), findsOneWidget);
      expect(find.text('Failed to load video'), findsNothing);
    },
  );

  testWidgets('a second failure in a row shows the error', (tester) async {
    await pump(tester, freshLinks());
    await tester.runAsync(() async {
      platform.failAfterStart(1);
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      platform.failAfterStart(2);
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    expect(find.text('Failed to load video'), findsOneWidget);
  });
}
