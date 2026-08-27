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
}
