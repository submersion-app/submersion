import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_playback_provider.dart';

void main() {
  group('PlaybackNotifier', () {
    test('default speed is 30x and presets are the compressed set', () {
      final notifier = PlaybackNotifier();
      expect(notifier.state.playbackSpeed, 30.0);
      expect(PlaybackNotifier.speedPresets, [
        1.0,
        5.0,
        15.0,
        30.0,
        60.0,
        120.0,
      ]);
    });

    test('1 wall-second at 30x advances 30 dive-seconds', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(3600);
        notifier.togglePlaybackMode();
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, 30);
        notifier.pause();
      });
    });

    test('1 wall-second at 120x advances 120 dive-seconds', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(3600);
        notifier.togglePlaybackMode();
        notifier.setSpeed(120);
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, 120);
        notifier.pause();
      });
    });

    test('clamps at dive end and pauses', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(60);
        notifier.togglePlaybackMode();
        notifier.setSpeed(120);
        notifier.play();
        async.elapse(const Duration(seconds: 2));
        expect(notifier.state.currentTimestamp, 60);
        expect(notifier.state.isPlaying, isFalse);
      });
    });

    test('setSpeed clamps to the 1-120 range', () {
      final notifier = PlaybackNotifier();
      notifier.initialize(600);
      notifier.setSpeed(0.1);
      expect(notifier.state.playbackSpeed, 1.0);
      notifier.setSpeed(500);
      expect(notifier.state.playbackSpeed, 120.0);
    });

    test('seeking while playing continues from the new position', () {
      fakeAsync((async) {
        final notifier = PlaybackNotifier();
        notifier.initialize(3600);
        notifier.togglePlaybackMode();
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        notifier.seekTo(600);
        expect(notifier.state.isPlaying, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, 630);
        notifier.pause();
      });
    });
  });

  group('a series that starts before the primary (#4296)', () {
    PlaybackNotifier started() {
      final notifier = PlaybackNotifier();
      notifier.initialize(2400, startSeconds: -600);
      notifier.togglePlaybackMode();
      return notifier;
    }

    test('starts and skips back to the first sample, not to 0', () {
      final notifier = started();
      expect(notifier.state.minTimestamp, -600);
      expect(notifier.state.currentTimestamp, -600);
      expect(notifier.state.atStart, isTrue);
      notifier.seekTo(300);
      notifier.skipToStart();
      expect(notifier.state.currentTimestamp, -600);
    });

    test('seeks and steps below 0, down to the first sample', () {
      final notifier = started();
      notifier.seekTo(-200);
      expect(notifier.state.currentTimestamp, -200);
      notifier.seekTo(-5000);
      expect(notifier.state.currentTimestamp, -600);
      notifier.seekTo(-595);
      notifier.stepBackward();
      expect(notifier.state.currentTimestamp, -600);
    });

    test('progress spans the whole series', () {
      final notifier = started();
      expect(notifier.state.progress, 0);
      notifier.seekToProgress(0.5);
      expect(notifier.state.currentTimestamp, 900);
      expect(notifier.state.progress, 0.5);
    });

    test('plays up through 0 from before it', () {
      fakeAsync((async) {
        final notifier = started();
        notifier.play();
        async.elapse(const Duration(seconds: 1));
        expect(notifier.state.currentTimestamp, -570);
        notifier.pause();
      });
    });

    test('times before 0 read with a sign', () {
      final notifier = started();
      notifier.seekTo(-65);
      expect(notifier.state.formattedTime, '-01:05');
    });
  });
}
