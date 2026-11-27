import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/video_controls_bar.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';
import 'package:submersion/features/species_id/presentation/providers/video_sighting_providers.dart';

import '../../../../helpers/test_database.dart';
import 'video_viewer_test_harness.dart';

/// Records every seek, so a test can tell where the viewer started a clip.
class _SeekRecorder extends FakeVideoPlatform {
  final seeks = <Duration>[];

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      seeks.add(position);
}

/// The viewer opened from a sighting row's photo chip opens each video at
/// the species' first sighting in it (issue #5084).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(tearDownTestDatabase);

  Override sightingsOf(String mediaId, List<VideoStretch> stretches) =>
      videoSpeciesSightingsProvider((
        mediaId: mediaId,
        speciesId: 's1',
      )).overrideWith((ref) async => stretches);

  /// Lets a pending lookup and its seek land.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  testWidgets('seeks the video to the first sighting', (tester) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      focusSpeciesId: 's1',
      overrides: [
        sightingsOf('v1', const [
          (startMs: 4200, endMs: 9000),
          (startMs: 15000, endMs: 16000),
        ]),
      ],
    );
    await settle(tester);

    expect(player.seeks, [const Duration(milliseconds: 4200)]);
  });

  testWidgets('a video with no timed sighting stays at the start', (
    tester,
  ) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      focusSpeciesId: 's1',
      overrides: [sightingsOf('v1', const [])],
    );
    await settle(tester);

    expect(player.seeks, isEmpty);
  });

  testWidgets('without a species it does not seek', (tester) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      overrides: [
        sightingsOf('v1', const [(startMs: 4200, endMs: 9000)]),
      ],
    );
    await settle(tester);

    expect(player.seeks, isEmpty);
  });

  testWidgets('a start position wins over the first sighting', (tester) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      focusSpeciesId: 's1',
      initialVideoPosition: const Duration(milliseconds: 1000),
      overrides: [
        sightingsOf('v1', const [(startMs: 4200, endMs: 9000)]),
      ],
    );
    await settle(tester);

    expect(player.seeks, [const Duration(milliseconds: 1000)]);
  });

  testWidgets('a video already playing when the lookup lands is not moved', (
    tester,
  ) async {
    final player = _SeekRecorder();
    final lookup = Completer<List<VideoStretch>>();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      focusSpeciesId: 's1',
      overrides: [
        videoSpeciesSightingsProvider((
          mediaId: 'v1',
          speciesId: 's1',
        )).overrideWith((ref) => lookup.future),
      ],
    );

    final playPause = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Play or pause video',
    );
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));
    expect(player.playing, isTrue);

    lookup.complete(const [(startMs: 4200, endMs: 9000)]);
    await settle(tester);

    expect(player.seeks, isEmpty);
    // Paused again, so no playback timer outlives the test.
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('each video paged to opens at its own first sighting', (
    tester,
  ) async {
    final player = _SeekRecorder();
    await pumpVideoViewer(
      tester,
      prefs,
      platform: player,
      focusSpeciesId: 's1',
      mediaList: [video('v1'), video('v2')],
      overrides: [
        sightingsOf('v1', const [(startMs: 4200, endMs: 9000)]),
        sightingsOf('v2', const [(startMs: 12000, endMs: 13000)]),
      ],
    );
    await settle(tester);
    expect(player.seeks, [const Duration(milliseconds: 4200)]);

    Future<void> page(Offset by) async {
      await tester.fling(find.byType(MediaViewerPage), by, 2000);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        player.completeInitialization();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await settle(tester);
    }

    await page(const Offset(-700, 0));
    expect(player.seeks.last, const Duration(milliseconds: 12000));

    // Back: the first video's player opens anew, at its sighting again.
    await page(const Offset(700, 0));
    expect(player.seeks, [
      const Duration(milliseconds: 4200),
      const Duration(milliseconds: 12000),
      const Duration(milliseconds: 4200),
    ]);
  });

  testWidgets('the controls bar follows the species', (tester) async {
    await pumpVideoViewer(
      tester,
      prefs,
      platform: _SeekRecorder(),
      focusSpeciesId: 's1',
      overrides: [
        sightingsOf('v1', const [(startMs: 4200, endMs: 9000)]),
      ],
    );
    await settle(tester);

    final bar = tester.widget<VideoControlsBar>(find.byType(VideoControlsBar));
    expect(bar.speciesId, 's1');
  });

  testWidgets(
    'a video the diver moved by hand stays put, even near its start',
    (tester) async {
      final player = _SeekRecorder();
      final lookup = Completer<List<VideoStretch>>();
      await pumpVideoViewer(
        tester,
        prefs,
        platform: player,
        focusSpeciesId: 's1',
        overrides: [
          videoSpeciesSightingsProvider((
            mediaId: 'v1',
            speciesId: 's1',
          )).overrideWith((ref) => lookup.future),
        ],
      );

      // Back to the very start by hand, before the lookup lands.
      final track = tester.getRect(find.byKey(VideoControlsBar.trackKey));
      await tester.tapAt(Offset(track.left + 1, track.center.dy));
      await tester.pump();
      final byHand = List.of(player.seeks);
      expect(byHand, isNotEmpty);

      lookup.complete(const [(startMs: 4200, endMs: 9000)]);
      await settle(tester);

      expect(player.seeks, byHand);
    },
  );

  testWidgets('the fullscreen bar follows the species too', (tester) async {
    await pumpVideoViewer(
      tester,
      prefs,
      platform: _SeekRecorder(),
      focusSpeciesId: 's1',
      overrides: [
        sightingsOf('v1', const [(startMs: 4200, endMs: 9000)]),
      ],
    );
    await settle(tester);

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pump();
    // The fullscreen controls show on a tap of the video.
    final playPause = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Play or pause video',
    );
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));

    final bar = tester.widget<VideoControlsBar>(find.byType(VideoControlsBar));
    expect(bar.speciesId, 's1');
    await tester.tap(playPause);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
