import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/media/presentation/widgets/video_color_filter.dart';
import 'package:video_player/video_player.dart';

const warm = AutoCorrectionParams(
  redFromGreen: 0.3,
  gainR: 2,
  gainG: 1,
  gainB: 0.8,
);

MediaItem video({ColorAdjustment? adjustment}) => MediaItem(
  id: 'v1',
  diveId: 'd1',
  mediaType: MediaType.video,
  sourceType: MediaSourceType.localFile,
  localPath: '/v/dive.mp4',
  durationSeconds: 30,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  colorAdjustment: adjustment,
);

/// Issue #3520: a playing video's correction follows the clip.
void main() {
  late ValueNotifier<VideoPlayerValue> player;

  setUp(() {
    player = ValueNotifier(
      const VideoPlayerValue(duration: Duration(seconds: 30)),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required MediaItem item,
    bool diverAuto = true,
    VideoColorTrack? track,
    double? Function(double)? depthAt,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diverAutoColorCorrectionProvider.overrideWithValue(diverAuto),
          videoColorTrackProvider.overrideWith((ref, key) async => track),
          videoDepthAtProvider.overrideWith((ref, key) async => depthAt),
        ],
        child: VideoColorFilter(
          item: item,
          player: player,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  ColorFilter? filterNow(WidgetTester tester) {
    final found = find.byType(ColorFiltered);
    return found.evaluate().isEmpty
        ? null
        : tester.widget<ColorFiltered>(found).colorFilter;
  }

  testWidgets('blends the track as the clip plays', (tester) async {
    await pump(
      tester,
      item: video(),
      track: const VideoColorTrack([
        VideoColorKey(seconds: 0, params: AutoCorrectionParams.none),
        VideoColorKey(seconds: 20, params: warm),
      ]),
    );
    expect(filterNow(tester), isNull);

    player.value = player.value.copyWith(position: const Duration(seconds: 10));
    await tester.pump();
    expect(
      filterNow(tester),
      ColorFilter.matrix(
        AutoCorrectionParams.lerp(
          AutoCorrectionParams.none,
          warm,
          0.5,
        ).toMatrix().values,
      ),
    );

    player.value = player.value.copyWith(position: const Duration(seconds: 25));
    await tester.pump();
    expect(filterNow(tester), ColorFilter.matrix(warm.toMatrix().values));
  });

  testWidgets('a surfaced moment drops the correction', (tester) async {
    await pump(
      tester,
      item: video(),
      track: const VideoColorTrack([VideoColorKey(seconds: 0, params: warm)]),
      depthAt: (s) => s > 15 ? 0 : 20,
    );
    expect(filterNow(tester), isNotNull);
    player.value = player.value.copyWith(position: const Duration(seconds: 20));
    await tester.pump();
    expect(filterNow(tester), isNull);
  });

  testWidgets('hand sliders shift the whole clip on top', (tester) async {
    const a = ColorAdjustment(warmth: 0.4);
    await pump(
      tester,
      item: video(adjustment: a),
      track: const VideoColorTrack([VideoColorKey(seconds: 0, params: warm)]),
    );
    expect(
      filterNow(tester),
      ColorFilter.matrix(composeCorrection(adjustment: a, auto: warm).values),
    );
  });

  testWidgets('auto off with no adjustment plays untouched', (tester) async {
    await pump(
      tester,
      item: video(),
      diverAuto: false,
      track: const VideoColorTrack([VideoColorKey(seconds: 0, params: warm)]),
    );
    expect(filterNow(tester), isNull);
  });

  testWidgets('no track yet plays untouched rather than failing', (
    tester,
  ) async {
    await pump(tester, item: video());
    expect(filterNow(tester), isNull);
  });
}
