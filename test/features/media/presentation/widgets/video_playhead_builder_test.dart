import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/presentation/helpers/playhead_interpolator.dart';
import 'package:submersion/features/media/presentation/widgets/video_playhead_builder.dart';

/// What a video overlay draws against: the playhead carried on between the
/// player's position reports (issue #4759).
void main() {
  late ValueNotifier<VideoPlayerValue> playback;
  late List<Duration> built;

  setUp(() {
    built = [];
    playback = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(seconds: 25),
        size: Size(1920, 1080),
        position: Duration(milliseconds: 1500),
        isInitialized: true,
      ),
    );
  });
  tearDown(() => playback.dispose());

  Future<void> pumpBuilder(
    WidgetTester tester, [
    ValueListenable<VideoPlayerValue>? source,
  ]) => tester.pumpWidget(
    VideoPlayheadBuilder(
      playback: source ?? playback,
      builder: (context, value, playhead) {
        built.add(playhead);
        return const SizedBox.shrink();
      },
    ),
  );

  testWidgets('paused, the playhead is the reported position', (tester) async {
    await pumpBuilder(tester);
    expect(built.last, const Duration(milliseconds: 1500));
    expect(tester.binding.hasScheduledFrame, isFalse);

    playback.value = playback.value.copyWith(
      position: const Duration(milliseconds: 4000),
    );
    await tester.pump();
    expect(built.last, const Duration(milliseconds: 4000));
  });

  testWidgets('playing, the playhead moves on between reports', (tester) async {
    playback.value = playback.value.copyWith(isPlaying: true);
    await pumpBuilder(tester);
    // The first frame times the report; the ones after carry it on.
    await tester.pump(const Duration(milliseconds: 16));
    final first = built.last;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(built.last, greaterThan(first));
    expect(
      built.last,
      lessThanOrEqualTo(
        const Duration(milliseconds: 1500) + PlayheadInterpolator.maxLead,
      ),
    );
  });

  testWidgets('a stalled player stops the frames at the lead cap', (
    tester,
  ) async {
    playback.value = playback.value.copyWith(isPlaying: true);
    await pumpBuilder(tester);
    await tester.pumpAndSettle();
    expect(
      built.last,
      const Duration(milliseconds: 1500) + PlayheadInterpolator.maxLead,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a buffering player holds the playhead where it is', (
    tester,
  ) async {
    playback.value = playback.value.copyWith(
      isPlaying: true,
      isBuffering: true,
    );
    await pumpBuilder(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(built.last, const Duration(milliseconds: 1500));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a new player is followed from its own position', (tester) async {
    await pumpBuilder(tester);
    final other = ValueNotifier(
      playback.value.copyWith(position: const Duration(milliseconds: 300)),
    );
    addTearDown(other.dispose);
    await pumpBuilder(tester, other);
    expect(built.last, const Duration(milliseconds: 300));

    // The old player is no longer heard.
    final before = built.length;
    playback.value = playback.value.copyWith(
      position: const Duration(seconds: 9),
    );
    await tester.pump();
    expect(built, hasLength(before));
  });
}
