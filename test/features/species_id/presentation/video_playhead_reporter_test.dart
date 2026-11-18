import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_playhead_reporter.dart';

import '../../media/presentation/support/media_widget_harness.dart';
import 'species_id_fakes.dart';

/// The viewer tells the scan where the diver is watching (issue #4709).
void main() {
  late RecordingIdentificationService service;
  late ValueNotifier<VideoPlayerValue> playback;

  late bool flagBefore;

  setUp(() {
    flagBefore = marineLifeIdEnabled;
    marineLifeIdEnabled = true;
    service = RecordingIdentificationService();
    playback = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(minutes: 3),
        isInitialized: true,
        isPlaying: true,
      ),
    );
  });
  tearDown(() {
    marineLifeIdEnabled = flagBefore;
    playback.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaIdentificationServiceProvider.overrideWithValue(service),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: VideoPlayheadReporter(
          playback: playback,
          item: testMediaItem(id: 'v1', mediaType: MediaType.video),
        ),
      ),
    ),
  );

  void at(int ms, {bool playing = true}) =>
      playback.value = playback.value.copyWith(
        position: Duration(milliseconds: ms),
        isPlaying: playing,
      );

  testWidgets('steady playback reports nothing', (tester) async {
    await pump(tester);
    for (var ms = 0; ms <= 10000; ms += 500) {
      at(ms);
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(service.followed, isEmpty);
  });

  testWidgets('a seek is reported once the playhead settles', (tester) async {
    await pump(tester);
    at(5000);
    await tester.pump(const Duration(milliseconds: 100));
    at(60000);
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.followed, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.followed, [(mediaId: 'v1', ms: 60000, seek: true)]);
    await tester.pump(const Duration(seconds: 2));
    expect(service.followed, hasLength(1));
  });

  testWidgets('a seek back is reported too', (tester) async {
    await pump(tester);
    at(60000);
    await tester.pump(const Duration(milliseconds: 100));
    at(30000);
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.followed.last, (mediaId: 'v1', ms: 30000, seek: true));
  });

  testWidgets('scrubbing reports only where it stops', (tester) async {
    await pump(tester);
    at(5000);
    await tester.pump(const Duration(milliseconds: 100));
    at(60000);
    await tester.pump(const Duration(milliseconds: 100));
    at(61000);
    await tester.pump(const Duration(milliseconds: 100));
    at(65000);
    await tester.pump(const Duration(milliseconds: 100));
    at(80000);
    await tester.pump(const Duration(milliseconds: 600));
    expect(service.followed, [(mediaId: 'v1', ms: 80000, seek: true)]);
  });

  testWidgets('pausing reports where it paused, once it settles', (
    tester,
  ) async {
    await pump(tester);
    at(5000);
    await tester.pump(const Duration(milliseconds: 250));
    at(5250, playing: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.followed, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.followed, [(mediaId: 'v1', ms: 5250, seek: false)]);
  });

  testWidgets('a scrub that pauses first reports only where it stops', (
    tester,
  ) async {
    await pump(tester);
    at(60000);
    await tester.pump(const Duration(milliseconds: 250));
    // The controls bar pauses the player as a drag starts.
    at(60000, playing: false);
    await tester.pump(const Duration(milliseconds: 100));
    at(90000, playing: false);
    await tester.pump(const Duration(milliseconds: 100));
    at(120000, playing: false);
    await tester.pump(const Duration(seconds: 1));
    expect(service.followed, [(mediaId: 'v1', ms: 120000, seek: true)]);
  });

  testWidgets('a pause undone before it settles reports nothing', (
    tester,
  ) async {
    await pump(tester);
    at(5000);
    await tester.pump(const Duration(milliseconds: 250));
    at(5250, playing: false);
    await tester.pump(const Duration(milliseconds: 200));
    at(5250);
    await tester.pump(const Duration(seconds: 1));
    expect(service.followed, isEmpty);
  });

  testWidgets('nothing is reported with the feature off', (tester) async {
    final before = marineLifeIdEnabled;
    marineLifeIdEnabled = false;
    addTearDown(() => marineLifeIdEnabled = before);
    await pump(tester);
    at(5000);
    await tester.pump(const Duration(milliseconds: 100));
    at(60000);
    await tester.pump(const Duration(seconds: 1));
    at(60500, playing: false);
    await tester.pump(const Duration(seconds: 1));
    expect(service.followed, isEmpty);
  });

  testWidgets('leaving the video forgets its report', (tester) async {
    await pump(tester);
    expect(service.forgotten, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(service.forgotten, ['v1']);
  });

  testWidgets('a pending seek is not reported after the viewer goes', (
    tester,
  ) async {
    await pump(tester);
    at(5000);
    await tester.pump(const Duration(milliseconds: 100));
    at(60000);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(service.followed, isEmpty);
  });
}
