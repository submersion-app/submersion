import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// In-memory player: reports a ready 30 second clip and records what the bar
/// asks of it, so a test can tell where it seeked and whether it plays.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  // One single-subscription stream per player, so its initialized event
  // waits for the controller to listen instead of being dropped.
  final _events = <int, StreamController<VideoEvent>>{};
  final seeks = <Duration>[];
  Duration _position = Duration.zero;
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
    _position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => _position;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();
}

/// Installs a fake player for this test, restoring the previous one when it
/// ends: CI runs many test files in one isolate (#2500).
_FakeVideoPlatform _usePlatform() {
  final platform = _FakeVideoPlatform();
  final original = VideoPlayerPlatform.instance;
  addTearDown(() => VideoPlayerPlatform.instance = original);
  VideoPlayerPlatform.instance = platform;
  return platform;
}

Future<VideoPlayerController> _readyController() async {
  final controller = VideoPlayerController.networkUrl(
    Uri.parse('https://example.invalid/clip.mp4'),
  );
  await controller.initialize();
  return controller;
}

Widget _app(Widget child, {TextDirection? direction}) {
  Widget body = Center(child: SizedBox(width: 500, child: child));
  if (direction != null) {
    body = Directionality(textDirection: direction, child: body);
  }
  return ProviderScope(
    overrides: [mediaPeopleChipsProvider('m1').overrideWith((ref) async => [])],
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
Offset _along(WidgetTester tester, double fraction) {
  final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
  return Offset(track.left + track.width * fraction, track.center.dy);
}

/// Unmounts the bar before releasing the player, so no listener outlives it
/// and no playback timer is left pending. The release runs on the real
/// clock: under the test's fake one, VideoPlayerController.dispose() never
/// completes.
Future<void> _finish(WidgetTester tester, VideoPlayerController c) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(c.dispose);
}

Matcher _closeToMs(int ms) => isA<Duration>().having(
  (d) => d.inMilliseconds,
  'milliseconds',
  closeTo(ms, 150),
);

void main() {
  testWidgets('dragging along the bar scrubs the video with the finger', (
    tester,
  ) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    final gesture = await tester.startGesture(_along(tester, 0.25));
    await gesture.moveTo(_along(tester, 0.5));
    await tester.pump();
    await gesture.moveTo(_along(tester, 0.75));
    await tester.pump();

    // Mid-drag: the video has already followed the finger, before release.
    expect(platform.seeks, isNotEmpty);
    expect(controller.value.position, _closeToMs(22500));
    expect(find.text('0:22'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(platform.seeks.last, _closeToMs(22500));
    expect(controller.value.position, _closeToMs(22500));
    await _finish(tester, controller);
  });

  testWidgets('a drag pauses a playing video and resumes it on release', (
    tester,
  ) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.play();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    final gesture = await tester.startGesture(_along(tester, 0.2));
    await gesture.moveTo(_along(tester, 0.6));
    await tester.pump();
    expect(platform.playing, isFalse, reason: 'paused while scrubbing');

    await gesture.up();
    await tester.pump();
    expect(platform.playing, isTrue, reason: 'resumed where it was let go');
    expect(controller.value.position, _closeToMs(18000));

    await controller.pause();
    await _finish(tester, controller);
  });

  testWidgets('a drag on a paused video leaves it paused', (tester) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    final gesture = await tester.startGesture(_along(tester, 0.2));
    await gesture.moveTo(_along(tester, 0.6));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(platform.playing, isFalse);
    await _finish(tester, controller);
  });

  testWidgets('a drag released at the very end does not restart the clip', (
    tester,
  ) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.play();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    final gesture = await tester.startGesture(_along(tester, 0.5));
    await gesture.moveTo(_along(tester, 1.2));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.value.position, const Duration(seconds: 30));
    expect(platform.playing, isFalse);
    await _finish(tester, controller);
  });

  testWidgets('a tap still jumps to the tapped point', (tester) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    await tester.tapAt(_along(tester, 0.5));
    await tester.pump();

    expect(platform.seeks.last, _closeToMs(15000));
    await _finish(tester, controller);
  });

  testWidgets('a drag on the bar scrubs instead of turning the page, '
      'while a swipe elsewhere still turns it', (tester) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    final pages = PageController();
    addTearDown(pages.dispose);
    // The media viewer's own pager: a PhotoViewGallery whose video pages are
    // fixed-scale custom children, with the bar inside the page.
    await tester.pumpWidget(
      _app(
        SizedBox(
          height: 400,
          child: PhotoViewGallery.builder(
            pageController: pages,
            scrollPhysics: const BouncingScrollPhysics(),
            itemCount: 2,
            builder: (context, index) =>
                PhotoViewGalleryPageOptions.customChild(
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained,
                  child: index == 0
                      ? Column(
                          children: [
                            const Expanded(
                              child: ColoredBox(color: Colors.blue),
                            ),
                            VideoControlsBar(
                              controller: controller,
                              mediaId: 'm1',
                            ),
                          ],
                        )
                      : const ColoredBox(color: Colors.red),
                ),
          ),
        ),
      ),
    );

    // A leftward drag on the bar would page forward if the pager took it.
    await tester.dragFrom(_along(tester, 0.8), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(pages.page, 0);
    expect(platform.seeks, isNotEmpty);

    await tester.dragFrom(
      tester.getCenter(find.byType(ColoredBox).first),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    await _finish(tester, controller);
  });

  testWidgets('the bar runs left to right in a right-to-left language', (
    tester,
  ) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.seekTo(const Duration(seconds: 10));
    await tester.pumpWidget(
      _app(
        VideoControlsBar(controller: controller, mediaId: 'm1'),
        direction: TextDirection.rtl,
      ),
    );

    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    // Elapsed time on the left, total on the right, as in every language.
    expect(
      tester.getCenter(find.text('0:10')).dx,
      lessThan(tester.getCenter(find.text('0:30')).dx),
    );
    // The filled part of the track grows from the left edge.
    expect(
      tester.getRect(find.byType(FractionallySizedBox)).left,
      moreOrLessEquals(track.left),
    );
    // And a tap a quarter of the way from the left lands a quarter in.
    await tester.tapAt(_along(tester, 0.25));
    await tester.pump();
    expect(platform.seeks.last, _closeToMs(7500));
    await _finish(tester, controller);
  });

  testWidgets('the thumb is drawn whole, not clipped to the thin track', (
    tester,
  ) async {
    _usePlatform();
    final controller = await _readyController();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    // The 16 px thumb overhangs the 4 px track; a clipping Stack drew it as
    // a flat sliver lost in the white progress fill.
    final stack = tester.widget<Stack>(
      find.descendant(
        of: find.byKey(VideoControlsBar.trackKey),
        matching: find.byType(Stack),
      ),
    );
    expect(stack.clipBehavior, Clip.none);
    await _finish(tester, controller);
  });
  testWidgets('reports a scrub starting and settling, and a tap as settled', (
    tester,
  ) async {
    _usePlatform();
    final controller = await _readyController();
    final reports = <bool>[];
    await tester.pumpWidget(
      _app(
        VideoControlsBar(
          controller: controller,
          mediaId: 'm1',
          onHoldChanged: reports.add,
        ),
      ),
    );

    // A tap is a seek that settles at once: the host may restart its clock.
    await tester.tapAt(_along(tester, 0.5));
    await tester.pump();
    expect(reports, [false]);

    final gesture = await tester.startGesture(_along(tester, 0.2));
    await gesture.moveTo(_along(tester, 0.6));
    await tester.pump();
    expect(reports, [false, true]);

    await gesture.up();
    await tester.pump();
    expect(reports, [false, true, false]);
    await _finish(tester, controller);
  });

  testWidgets('the mouse resting on the bar holds the host\'s controls, '
      'and a tap under it does not let them go', (tester) async {
    _usePlatform();
    final controller = await _readyController();
    final reports = <bool>[];
    await tester.pumpWidget(
      _app(
        VideoControlsBar(
          controller: controller,
          mediaId: 'm1',
          onHoldChanged: reports.add,
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(_along(tester, 0.5));
    await tester.pump();
    expect(reports, [true]);

    await mouse.down(_along(tester, 0.5));
    await mouse.up();
    await tester.pump();
    expect(reports, [true, true], reason: 'a tap seeks, the mouse still holds');

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(reports, [true, true, false]);
    await _finish(tester, controller);
  });

  testWidgets('a bar taken away mid-scrub lets the host\'s controls go '
      'after the frame', (tester) async {
    _usePlatform();
    final controller = await _readyController();
    final reports = <bool>[];
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, visible, _) => visible
              ? VideoControlsBar(
                  controller: controller,
                  mediaId: 'm1',
                  onHoldChanged: reports.add,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );

    final gesture = await tester.startGesture(_along(tester, 0.2));
    await gesture.moveTo(_along(tester, 0.6));
    await tester.pump();
    expect(reports, [true]);

    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(reports, [true, false]);
    await gesture.up();
    await _finish(tester, controller);
  });

  testWidgets('a screen reader can step the video forward and back', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.seekTo(const Duration(seconds: 10));
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    final bar = find.bySemanticsLabel('Seek video position');
    final node = find.semantics.byLabel('Seek video position');
    expect(
      tester.getSemantics(bar),
      isSemantics(
        label: 'Seek video position',
        value: '0:10',
        increasedValue: '0:15',
        decreasedValue: '0:05',
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );

    tester.semantics.performAction(node, SemanticsAction.increase);
    await tester.pump();
    expect(platform.seeks.last, const Duration(seconds: 15));

    tester.semantics.performAction(node, SemanticsAction.decrease);
    await tester.pump();
    expect(platform.seeks.last, const Duration(seconds: 10));

    await _finish(tester, controller);
    semantics.dispose();
  });

  testWidgets('a new video mid-scrub drops the old scrub', (tester) async {
    final platform = _usePlatform();
    final first = await _readyController();
    final second = await _readyController();
    final reports = <bool>[];
    Widget bar(VideoPlayerController c) => _app(
      VideoControlsBar(
        controller: c,
        mediaId: 'm1',
        onHoldChanged: reports.add,
      ),
    );
    await first.play();
    await tester.pumpWidget(bar(first));

    final gesture = await tester.startGesture(_along(tester, 0.2));
    await gesture.moveTo(_along(tester, 0.6));
    await tester.pump();
    await tester.pumpWidget(bar(second));
    final seeksBefore = platform.seeks.length;

    await gesture.moveTo(_along(tester, 0.9));
    await gesture.up();
    await tester.pump();

    // Nothing from the old drag reaches the new video, and it is not
    // started by the old video's resume-on-release.
    expect(platform.seeks.length, seeksBefore);
    expect(second.value.isPlaying, isFalse);
    expect(second.value.position, Duration.zero);
    expect(reports, [true, false]);

    await first.pause();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(first.dispose);
    await tester.runAsync(second.dispose);
  });
  testWidgets('the slider carries no stray tap or scroll actions, and quick '
      'steps add up', (tester) async {
    final semantics = tester.ensureSemantics();
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.seekTo(const Duration(seconds: 10));
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    final node = find.semantics.byLabel('Seek video position');
    final data = tester
        .getSemantics(find.bySemanticsLabel('Seek video position'))
        .getSemanticsData();
    // The gesture detector's own actions would fake a drag or tap from the
    // bar's centre and jump the video there.
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.hasAction(SemanticsAction.scrollLeft), isFalse);
    expect(data.hasAction(SemanticsAction.scrollRight), isFalse);

    // Two steps before the first seek settles land two steps on.
    tester.semantics.performAction(node, SemanticsAction.increase);
    tester.semantics.performAction(node, SemanticsAction.increase);
    await tester.pump();
    expect(platform.seeks.last, const Duration(seconds: 20));

    await _finish(tester, controller);
    semantics.dispose();
  });

  testWidgets('a new video mid-scrub tells the host after the frame, so the '
      'host can rebuild', (tester) async {
    _usePlatform();
    final first = await _readyController();
    final second = await _readyController();
    var current = first;
    final reports = <bool>[];
    late StateSetter setHost;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            setHost = setState;
            return VideoControlsBar(
              controller: current,
              mediaId: 'm1',
              // A host that rebuilds on the report, as the media viewer's
              // fullscreen controls do.
              onHoldChanged: (scrubbing) =>
                  setState(() => reports.add(scrubbing)),
            );
          },
        ),
      ),
    );

    final gesture = await tester.startGesture(_along(tester, 0.2));
    await gesture.moveTo(_along(tester, 0.6));
    await tester.pump();
    setHost(() => current = second);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(reports, [true, false]);

    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(first.dispose);
    await tester.runAsync(second.dispose);
  });
  testWidgets('a second drag begun before the first settles still resumes '
      'a playing video', (tester) async {
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.play();
    await tester.pumpWidget(
      _app(VideoControlsBar(controller: controller, mediaId: 'm1')),
    );

    platform.seekGate = Completer<void>();
    final first = await tester.startGesture(_along(tester, 0.2));
    await first.moveTo(_along(tester, 0.4));
    await tester.pump();
    await first.up();
    await tester.pump();
    // The release is still waiting on its seek when the next drag begins.
    final second = await tester.startGesture(_along(tester, 0.5));
    await second.moveTo(_along(tester, 0.7));
    await tester.pump();
    platform.seekGate!.complete();
    platform.seekGate = null;
    await tester.pump();
    await second.up();
    await tester.pump();

    expect(platform.playing, isTrue);
    expect(controller.value.position, _closeToMs(21000));
    await controller.pause();
    await _finish(tester, controller);
  });
  testWidgets('a seek still running on the old video neither delays nor '
      'drops seeks on the new one', (tester) async {
    final platform = _usePlatform();
    final first = await _readyController();
    final second = await _readyController();
    var current = first;
    late StateSetter setHost;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            setHost = setState;
            return VideoControlsBar(controller: current, mediaId: 'm1');
          },
        ),
      ),
    );

    // The old video's seek hangs, then the video is replaced.
    platform
      ..gatedPlayer = first.playerId
      ..seekGate = Completer<void>();
    await tester.tapAt(_along(tester, 0.2));
    await tester.pump();
    setHost(() => current = second);
    await tester.pump();

    await tester.tapAt(_along(tester, 0.5));
    await tester.pump();
    expect(second.value.position, _closeToMs(15000));

    // The old seek failing late does not touch the new video's seeks.
    platform.seekGate!.completeError(StateError('decoder gone'));
    await tester.pump();
    await tester.tapAt(_along(tester, 0.8));
    await tester.pump();
    expect(second.value.position, _closeToMs(24000));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(first.dispose);
    await tester.runAsync(second.dispose);
  });
  testWidgets('quick screen-reader steps announce where the video is headed, '
      'and report as settled', (tester) async {
    final semantics = tester.ensureSemantics();
    final platform = _usePlatform();
    final controller = await _readyController();
    await controller.seekTo(const Duration(seconds: 10));
    final reports = <bool>[];
    await tester.pumpWidget(
      _app(
        VideoControlsBar(
          controller: controller,
          mediaId: 'm1',
          onHoldChanged: reports.add,
        ),
      ),
    );

    // The player is slow: neither step has landed when the slider is read.
    platform.seekGate = Completer<void>();
    final node = find.semantics.byLabel('Seek video position');
    tester.semantics.performAction(node, SemanticsAction.increase);
    tester.semantics.performAction(node, SemanticsAction.increase);
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Seek video position')),
      isSemantics(
        value: '0:20',
        increasedValue: '0:25',
        decreasedValue: '0:15',
      ),
    );
    expect(reports, [false, false]);

    platform.seekGate!.complete();
    platform.seekGate = null;
    await tester.pump();
    expect(controller.value.position, const Duration(seconds: 20));
    await _finish(tester, controller);
    semantics.dispose();
  });
}
