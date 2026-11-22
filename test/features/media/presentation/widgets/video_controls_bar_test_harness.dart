import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

// Shared by the video controls bar's tests: an in-memory player and the
// helpers that mount the bar and reach along its track.

/// In-memory player: reports a ready 30 second clip and records what the bar
/// asks of it, so a test can tell where it seeked and whether it plays.
class FakeBarVideoPlatform extends VideoPlayerPlatform {
  // One single-subscription stream per player, so its initialized event
  // waits for the controller to listen instead of being dropped.
  final _events = <int, StreamController<VideoEvent>>{};
  final seeks = <Duration>[];

  /// Where the player is: set it to move the clip, as playback would.
  Duration position = Duration.zero;
  bool playing = false;

  /// When set, seeks wait for it, as a slow decoder's would; only on
  /// [gatedPlayer] when that is set.
  Completer<void>? seekGate;
  int? gatedPlayer;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) => createWithOptions(
    VideoCreationOptions(
      dataSource: dataSource,
      viewType: VideoViewType.textureView,
    ),
  );

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _events.length + 1;
    (_events[playerId] = StreamController<VideoEvent>()).add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(640, 360),
        rotationCorrection: 0,
      ),
    );
    return playerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    playing = false;
    // Not awaited: the controller has already cancelled its subscription,
    // and close() on a single-subscription stream would wait forever.
    unawaited(_events[playerId]!.close());
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  /// Sends [event] from the player [playerId], as the platform would.
  void emit(int playerId, VideoEvent event) => _events[playerId]!.add(event);

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
  Future<void> seekTo(int playerId, Duration position) async {
    if (gatedPlayer == null || gatedPlayer == playerId) await seekGate?.future;
    seeks.add(position);
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();
}

/// Installs a fake player for this test, restoring the previous one when it
/// ends: CI runs many test files in one isolate (#2500).
FakeBarVideoPlatform useBarPlatform() {
  final platform = FakeBarVideoPlatform();
  final original = VideoPlayerPlatform.instance;
  addTearDown(() => VideoPlayerPlatform.instance = original);
  VideoPlayerPlatform.instance = platform;
  return platform;
}

Future<VideoPlayerController> readyController() async {
  final controller = VideoPlayerController.networkUrl(
    Uri.parse('https://example.invalid/clip.mp4'),
  );
  await controller.initialize();
  return controller;
}

Widget barApp(Widget child, {TextDirection? direction}) {
  Widget body = Center(child: SizedBox(width: 500, child: child));
  if (direction != null) {
    body = Directionality(textDirection: direction, child: body);
  }
  return ProviderScope(
    overrides: [
      mediaPeopleChipsProvider('m1').overrideWith((ref) async => []),
      // Nothing analysed to tint (issue #4825).
      videoScanStretchesProvider('m1').overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      // The tests read English labels, so the host's locale must not decide.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(backgroundColor: Colors.black, body: body),
    ),
  );
}

/// The point [fraction] of the way along the bar's track, from its left edge.
Offset along(WidgetTester tester, double fraction) {
  final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
  return Offset(track.left + track.width * fraction, track.center.dy);
}

/// Unmounts the bar before releasing the player, so no listener outlives it
/// and no playback timer is left pending. The release runs on the real
/// clock: under the test's fake one, VideoPlayerController.dispose() never
/// completes.
Future<void> finishBar(WidgetTester tester, VideoPlayerController c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(c.dispose);
}

Matcher closeToMs(int ms) => isA<Duration>().having(
  (d) => d.inMilliseconds,
  'milliseconds',
  closeTo(ms, 150),
);
