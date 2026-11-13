import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';

import '../../../../helpers/test_database.dart';
import 'video_viewer_test_harness.dart';

/// The viewer's video controls follow the mouse as desktop players do
/// (#4487): a move brings them up, and while the video plays they go once
/// the mouse rests or leaves the window.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(tearDownTestDatabase);

  final track = find.byKey(VideoControlsBar.trackKey);
  final playPause = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Play or pause video',
  );

  /// A tap on the video, which PhotoView's double-tap recognizer holds
  /// until its timeout.
  Future<void> tapVideo(WidgetTester tester) async {
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Delivers a play report from the player. Its event stream was opened
  /// inside runAsync, so its events arrive on the real clock.
  Future<void> report(
    WidgetTester tester,
    FakeVideoPlatform platform, {
    required bool playing,
  }) async {
    await tester.runAsync(() async {
      platform.reportPlaying(playing);
      await Future<void>.delayed(Duration.zero);
    });
  }

  /// Pauses a playing clip, so the player's position timer is not left
  /// pending when the test ends.
  Future<void> stopPlayback(
    WidgetTester tester,
    FakeVideoPlatform platform,
  ) async {
    if (platform.playing) await tapVideo(tester);
    await tester.pump(const Duration(seconds: 5));
  }

  Future<TestGesture> mouseOver(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(playPause));
    addTearDown(() => mouse.removePointer());
    return mouse;
  }

  testWidgets('a mouse move brings a playing video\'s controls back, and '
      'they go once it rests', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);

    await tapVideo(tester);
    expect(platform.playing, isTrue);
    expect(track, findsNothing, reason: 'playing hides the overlay');

    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    expect(track, findsOneWidget);

    // Each move restarts the clock.
    await tester.pump(const Duration(seconds: 2));
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump(const Duration(seconds: 2));
    expect(track, findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(track, findsNothing);
    await stopPlayback(tester, platform);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the window hides a playing video\'s controls at '
      'once; a paused video keeps them', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);

    await tapVideo(tester);
    var mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    expect(track, findsOneWidget);
    await mouse.removePointer();
    await tester.pump();
    expect(track, findsNothing);

    // Paused: the controls stay, rested or gone.
    await tapVideo(tester);
    expect(platform.playing, isFalse);
    mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump(const Duration(seconds: 5));
    expect(track, findsOneWidget);
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 5));
    expect(track, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in fullscreen a mouse move reveals the exit button and the '
      'bar, and they go once it rests', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);
    final exitButton = find.byTooltip('Exit full screen');

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    await tapVideo(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(exitButton, findsNothing);

    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    expect(exitButton, findsOneWidget);
    expect(track, findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(exitButton, findsNothing);
    expect(track, findsNothing);
    await stopPlayback(tester, platform);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mouse scrub holds the controls, which go 3 s after the '
      'release', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);

    await tapVideo(tester);
    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    expect(track, findsOneWidget);
    await mouse.moveTo(tester.getCenter(track));
    await tester.pump();

    await mouse.down(tester.getCenter(track));
    await mouse.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(platform.playing, isFalse, reason: 'paused while scrubbing');
    await tester.pump(const Duration(seconds: 4));
    expect(track, findsOneWidget, reason: 'not pulled from under the mouse');

    await mouse.up();
    await tester.pump();
    expect(platform.playing, isTrue);
    expect(track, findsOneWidget);
    // Still on the bar, the mouse holds them; off it, the clock runs.
    await tester.pump(const Duration(seconds: 4));
    expect(track, findsOneWidget);
    await mouse.moveTo(tester.getCenter(playPause));
    await tester.pump(const Duration(seconds: 3));
    expect(track, findsNothing);
    await stopPlayback(tester, platform);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the controls follow the player\'s own play reports, so a '
      'late one neither strands the play icon nor the controls', (
    tester,
  ) async {
    final platform = await pumpVideoViewer(tester, prefs);
    final playIcon = find.byIcon(Icons.play_arrow);

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    // Play, then pause: the controls and play icon stay up.
    await tapVideo(tester);
    await tapVideo(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(track, findsOneWidget);
    expect(playIcon, findsOneWidget);

    // The player reports playing on its own (as after a seek): the icon
    // goes now, and the controls 3 s later.
    await report(tester, platform, playing: true);
    await tester.pump();
    expect(playIcon, findsNothing);
    expect(track, findsOneWidget);
    // The report arrived on the real clock, so the clock it started runs
    // there too.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 3200)),
    );
    await tester.pump();
    expect(track, findsNothing);

    // Revealed while playing, then the player stops (the clip ended): the
    // controls stay rather than leave a paused video bare.
    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    await report(tester, platform, playing: false);
    await tester.pump(const Duration(seconds: 5));
    expect(track, findsOneWidget);
    expect(playIcon, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the controls stay up while the mouse rests on the bar, and '
      'go 3 s after it moves off', (tester) async {
    final platform = await pumpVideoViewer(tester, prefs);

    await tapVideo(tester);
    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(track));
    await tester.pump(const Duration(seconds: 5));
    expect(track, findsOneWidget, reason: 'held under the mouse');

    await mouse.moveTo(tester.getCenter(playPause));
    await tester.pump(const Duration(seconds: 2));
    expect(track, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(track, findsNothing);
    await stopPlayback(tester, platform);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the window from the bar hides the controls at once', (
    tester,
  ) async {
    final platform = await pumpVideoViewer(tester, prefs);

    await tapVideo(tester);
    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(track));
    await tester.pump();
    await mouse.removePointer();
    await tester.pump();
    expect(track, findsNothing);
    await stopPlayback(tester, platform);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bar hidden mid-scrub lets the controls go again', (
    tester,
  ) async {
    final platform = await pumpVideoViewer(tester, prefs);

    await tapVideo(tester);
    final mouse = await mouseOver(tester);
    await mouse.moveBy(const Offset(5, 5));
    await tester.pump();
    await mouse.down(tester.getCenter(track));
    await mouse.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(platform.playing, isFalse, reason: 'paused while scrubbing');

    // Space plays the video mid-drag, which hides the overlay and the bar.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(platform.playing, isTrue);
    expect(track, findsNothing);
    await mouse.up();
    await tester.pump(const Duration(seconds: 1));
    expect(track, findsNothing, reason: 'the hold released, not revealed');

    // Away from where the bar was, a move reveals on the usual clock.
    await mouse.moveTo(tester.getCenter(playPause) - const Offset(0, 100));
    await tester.pump();
    expect(track, findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(track, findsNothing);
    await stopPlayback(tester, platform);
    expect(tester.takeException(), isNull);
  });
}
