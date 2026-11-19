import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/helpers/playhead_interpolator.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'video_controls_bar_test_harness.dart';

/// The bar while a video plays: the thumb glides between the player's
/// position reports (issue #4732).
void main() {
  group('while playing (issue #4732)', () {
    /// Where the thumb's centre sits along the track for [position].
    double thumbXAt(WidgetTester tester, Duration position) {
      final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
      return track.left +
          track.width *
              position.inMilliseconds /
              const Duration(seconds: 30).inMilliseconds;
    }

    double thumbX(WidgetTester tester) =>
        tester.getCenter(find.byKey(VideoControlsBar.thumbKey)).dx;

    /// A playing video whose player last reported 0:15, drawn on the frame
    /// after that report.
    Future<(FakeBarVideoPlatform, VideoPlayerController)> playingAt15(
      WidgetTester tester,
    ) async {
      final platform = useBarPlatform();
      final controller = await readyController();
      await tester.pumpWidget(
        barApp(VideoControlsBar(controller: controller, mediaId: 'm1')),
      );
      platform.position = const Duration(seconds: 15);
      await controller.play();
      // The controller polls the player every 100 ms while playing.
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value.position, const Duration(seconds: 15));
      return (platform, controller);
    }

    testWidgets('the thumb glides between the player\'s position reports', (
      tester,
    ) async {
      final (_, controller) = await playingAt15(tester);
      expect(
        thumbX(tester),
        closeTo(thumbXAt(tester, const Duration(seconds: 15)), 0.01),
      );

      // Frames before the next poll: the player has not reported again.
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));

      expect(controller.value.position, const Duration(seconds: 15));
      expect(
        thumbX(tester),
        closeTo(thumbXAt(tester, const Duration(milliseconds: 15060)), 0.01),
      );

      await controller.pause();
      await finishBar(tester, controller);
    });

    testWidgets('a stalled player leaves the thumb resting a moment ahead, '
        'with no frames left pending', (tester) async {
      final (_, controller) = await playingAt15(tester);

      // Settles although the video still plays: the player never moves on.
      await tester.pumpAndSettle();

      expect(
        thumbX(tester),
        closeTo(
          thumbXAt(
            tester,
            const Duration(seconds: 15) + PlayheadInterpolator.maxLead,
          ),
          0.01,
        ),
      );

      await controller.pause();
      await finishBar(tester, controller);
    });

    testWidgets('a buffered-range update does not stall the glide', (
      tester,
    ) async {
      final (platform, controller) = await playingAt15(tester);
      await tester.pump(const Duration(milliseconds: 30));

      platform.emit(
        controller.playerId,
        VideoEvent(
          eventType: VideoEventType.bufferingUpdate,
          buffered: [DurationRange(Duration.zero, const Duration(seconds: 20))],
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));

      expect(controller.value.position, const Duration(seconds: 15));
      expect(
        thumbX(tester),
        closeTo(thumbXAt(tester, const Duration(milliseconds: 15090)), 0.01),
      );

      await controller.pause();
      await finishBar(tester, controller);
    });

    testWidgets('a tap just behind the gliding thumb puts it where tapped', (
      tester,
    ) async {
      final (_, controller) = await playingAt15(tester);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        thumbX(tester),
        closeTo(thumbXAt(tester, const Duration(milliseconds: 15120)), 0.01),
      );

      final target = thumbXAt(tester, const Duration(milliseconds: 15050));
      await tester.tapAt(Offset(target, along(tester, 0).dy));
      await tester.pump();

      expect(controller.value.position, closeToMs(15050));
      expect(thumbX(tester), closeTo(target, 0.05));

      await controller.pause();
      await finishBar(tester, controller);
    });

    testWidgets('buffering stops the thumb where it is drawn, without a '
        'step back, and stops asking for frames', (tester) async {
      final (platform, controller) = await playingAt15(tester);
      await tester.pump(const Duration(milliseconds: 50));
      final drawn = thumbXAt(tester, const Duration(milliseconds: 15050));
      expect(thumbX(tester), closeTo(drawn, 0.01));

      platform.emit(
        controller.playerId,
        VideoEvent(eventType: VideoEventType.bufferingStart),
      );
      await tester.pump();

      // The player still says 0:15, its last poll: a buffering flag does not
      // refresh it.
      expect(controller.value.isBuffering, isTrue);
      expect(thumbX(tester), closeTo(drawn, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await controller.pause();
      await finishBar(tester, controller);
    });

    testWidgets('pausing stops the thumb where it is drawn, without a step '
        'back', (tester) async {
      final (_, controller) = await playingAt15(tester);
      await tester.pump(const Duration(milliseconds: 50));
      final drawn = thumbXAt(tester, const Duration(milliseconds: 15050));
      expect(thumbX(tester), closeTo(drawn, 0.01));

      // pause() does not refresh the position: it stays the 0:15 poll.
      await controller.pause();
      await tester.pump();

      expect(controller.value.position, const Duration(seconds: 15));
      expect(thumbX(tester), closeTo(drawn, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await finishBar(tester, controller);
    });

    testWidgets('reaching the end keeps the thumb at the end while the '
        'player seeks there', (tester) async {
      final platform = useBarPlatform();
      final controller = await readyController();
      await tester.pumpWidget(
        barApp(VideoControlsBar(controller: controller, mediaId: 'm1')),
      );
      platform.position = const Duration(milliseconds: 29950);
      await controller.play();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));
      final end = thumbXAt(tester, const Duration(seconds: 30));
      expect(thumbX(tester), closeTo(end, 0.01));

      // The player finishes: video_player pauses, then seeks to the end, and
      // a real decoder takes frames to get there.
      platform.seekGate = Completer<void>();
      platform.emit(
        controller.playerId,
        VideoEvent(eventType: VideoEventType.completed),
      );
      // The event is handled after the first frame is drawn; the second
      // draws the paused bar.
      await tester.pump();
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      expect(thumbX(tester), closeTo(end, 0.01));

      platform.seekGate!.complete();
      platform.seekGate = null;
      await tester.pump();
      expect(controller.value.position, const Duration(seconds: 30));
      expect(thumbX(tester), closeTo(end, 0.01));
      await finishBar(tester, controller);
    });
  });
}
