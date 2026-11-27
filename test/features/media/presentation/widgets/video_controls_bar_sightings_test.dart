import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/presentation/helpers/video_diver_moves.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';
import 'package:submersion/features/species_id/presentation/providers/video_sighting_providers.dart';

import 'package:video_player/video_player.dart';

import 'video_controls_bar_test_harness.dart';

/// A species' sightings on the scrub bar, and the button that steps
/// through them, in the viewer opened from a sighting row (issue #5084).
void main() {
  const key = (mediaId: 'm1', speciesId: 's1');

  Override sightings(List<VideoStretch> stretches) =>
      videoSpeciesSightingsProvider(key).overrideWith((ref) async => stretches);

  final next = find.byKey(VideoControlsBar.nextSightingKey);
  Finder mark(int startMs) =>
      find.byKey(ValueKey('videoSightingMark_$startMs'));

  Future<void> pumpBar(
    WidgetTester tester,
    VideoPlayerController controller, {
    String? speciesId = 's1',
    List<VideoStretch> stretches = const [],
  }) async {
    await tester.pumpWidget(
      barApp(
        VideoControlsBar(
          controller: controller,
          mediaId: 'm1',
          speciesId: speciesId,
        ),
        overrides: [sightings(stretches)],
      ),
    );
    await tester.pump();
  }

  testWidgets('without a species there are no marks and no button', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      speciesId: null,
      stretches: const [
        (startMs: 3000, endMs: 6000),
        (startMs: 20000, endMs: 22000),
      ],
    );

    expect(mark(3000), findsNothing);
    expect(next, findsNothing);
    await finishBar(tester, controller);
  });

  testWidgets('a sighting is a band over its stretch of the track', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: const [(startMs: 3000, endMs: 6000)],
    );

    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    final band = tester.getRect(mark(3000));
    expect(band.left - track.left, closeTo(track.width * 0.1, 1));
    expect(band.width, closeTo(track.width * 0.1, 1));
    // One sighting: nothing to step to.
    expect(next, findsNothing);
    await finishBar(tester, controller);
  });

  testWidgets('a moment-long sighting still shows', (tester) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: const [(startMs: 15000, endMs: 15000)],
    );

    expect(tester.getSize(mark(15000)).width, 3);
    await finishBar(tester, controller);
  });

  testWidgets('a video tagged by hand has no marks and no button', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(tester, controller);

    expect(
      find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('videoSightingMark_');
      }),
      findsNothing,
    );
    expect(next, findsNothing);
    await finishBar(tester, controller);
  });

  testWidgets('Next sighting steps through them and wraps', (tester) async {
    final platform = useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: const [
        (startMs: 3000, endMs: 6000),
        (startMs: 20000, endMs: 22000),
      ],
    );

    expect(next, findsOneWidget);
    expect(find.byTooltip('Next sighting'), findsOneWidget);

    await tester.tap(next);
    await tester.pump();
    expect(platform.seeks.last, const Duration(milliseconds: 3000));

    await tester.tap(next);
    await tester.pump();
    expect(platform.seeks.last, const Duration(milliseconds: 20000));

    await tester.tap(next);
    await tester.pump();
    expect(platform.seeks.last, const Duration(milliseconds: 3000));
    await finishBar(tester, controller);
  });

  testWidgets('Next sighting keeps a playing video playing', (tester) async {
    final platform = useBarPlatform();
    final controller = await readyController();
    await controller.play();
    await pumpBar(
      tester,
      controller,
      stretches: const [
        (startMs: 3000, endMs: 6000),
        (startMs: 20000, endMs: 22000),
      ],
    );

    await tester.tap(next);
    await tester.pump();
    expect(platform.seeks.last, const Duration(milliseconds: 3000));
    expect(platform.playing, isTrue);
    await finishBar(tester, controller);
  });

  testWidgets('Next sighting leaves a paused video paused', (tester) async {
    final platform = useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: const [
        (startMs: 3000, endMs: 6000),
        (startMs: 20000, endMs: 22000),
      ],
    );

    await tester.tap(next);
    await tester.pump();
    expect(platform.playing, isFalse);
    await finishBar(tester, controller);
  });

  testWidgets('many sightings stay on one row inside the track', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: [
        for (var i = 0; i < 50; i++) (startMs: i * 600, endMs: i * 600 + 200),
      ],
    );

    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    final tops = <double>{};
    for (var i = 0; i < 50; i++) {
      final band = tester.getRect(mark(i * 600));
      tops.add(band.top);
      expect(band.left, greaterThanOrEqualTo(track.left - 0.01));
      expect(band.right, lessThanOrEqualTo(track.right + 0.01));
    }
    expect(tops, hasLength(1));
    await finishBar(tester, controller);
  });

  testWidgets('a sighting at the very end stays inside the track', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: const [(startMs: 30000, endMs: 30000)],
    );

    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    final band = tester.getRect(mark(30000));
    expect(band.right, lessThanOrEqualTo(track.right + 0.01));
    expect(band.width, 3);
    await finishBar(tester, controller);
  });

  testWidgets('a band stands proud of the 4 px track and its analysed tint', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(
      tester,
      controller,
      stretches: const [(startMs: 3000, endMs: 6000)],
    );

    final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
    final band = tester.getRect(mark(3000));
    expect(band.height, 6);
    expect(band.center.dy, closeTo(track.center.dy, 0.01));
    await finishBar(tester, controller);
  });

  testWidgets('the button holds its place while the sightings load', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    final lookup = Completer<List<VideoStretch>>();
    await tester.pumpWidget(
      barApp(
        VideoControlsBar(
          controller: controller,
          mediaId: 'm1',
          speciesId: 's1',
        ),
        overrides: [
          videoSpeciesSightingsProvider(
            key,
          ).overrideWith((ref) => lookup.future),
        ],
      ),
    );
    await tester.pump();
    final loading = tester.getRect(find.text('0:30'));

    lookup.complete(const [
      (startMs: 3000, endMs: 6000),
      (startMs: 20000, endMs: 22000),
    ]);
    await tester.pump();
    await tester.pump();

    expect(next, findsOneWidget);
    expect(tester.getRect(find.text('0:30')), loading);
    await finishBar(tester, controller);
  });

  testWidgets('a seek by hand marks the player as moved by the diver', (
    tester,
  ) async {
    useBarPlatform();
    final controller = await readyController();
    await pumpBar(tester, controller);
    expect(diverMoved(controller), isFalse);

    await tester.tapAt(along(tester, 0.5));
    await tester.pump();

    expect(diverMoved(controller), isTrue);
    await finishBar(tester, controller);
  });
}
