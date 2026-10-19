import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/media/presentation/widgets/color_corrected.dart';

Uint8List blueRgba() => Uint8List.fromList([
  for (var i = 0; i < 64; i++) ...[20, 100, 160, 255],
]);

MediaItem item({
  String? diveId = 'd1',
  double? depth = 18,
  MatchConfidence confidence = MatchConfidence.interpolated,
  int? offset,
  MediaType type = MediaType.photo,
  ColorAdjustment? adjustment,
}) => MediaItem(
  id: 'm1',
  diveId: diveId,
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  colorAdjustment: adjustment,
  enrichment: depth == null
      ? null
      : MediaEnrichment(
          id: 'e1',
          mediaId: 'm1',
          diveId: 'd1',
          depthMeters: depth,
          elapsedSeconds: 600,
          matchConfidence: confidence,
          timestampOffsetSeconds: offset,
          createdAt: DateTime.utc(2026),
        ),
);

void main() {
  final source = MemoryImage(Uint8List(0));

  Future<ProviderContainer> pump(
    WidgetTester tester,
    MediaItem item, {
    bool diverAuto = false,
    VideoColorTrack? track,
    MediaEnrichment? stored,
  }) async {
    final container = ProviderContainer(
      overrides: [
        colorEnrichmentProvider.overrideWith((ref, id) async => stored),
        diverAutoColorCorrectionProvider.overrideWithValue(diverAuto),
        colorAnalysisServiceProvider.overrideWithValue(
          ColorAnalysisService(decodeRgba: (_) async => blueRgba()),
        ),
        if (track != null)
          videoColorTrackProvider.overrideWith((ref, key) async => track),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ColorCorrected(
          item: item,
          analysisSource: source,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  ColorFiltered? filter(WidgetTester tester) {
    final found = find.byType(ColorFiltered);
    return found.evaluate().isEmpty
        ? null
        : tester.widget<ColorFiltered>(found);
  }

  testWidgets('no adjustment and auto off draws the child as it is', (
    tester,
  ) async {
    await pump(tester, item());
    expect(filter(tester), isNull);
  });

  testWidgets('a hand adjustment draws its matrix', (tester) async {
    const a = ColorAdjustment(warmth: 0.5);
    await pump(tester, item(adjustment: a));
    expect(
      filter(tester)!.colorFilter,
      ColorFilter.matrix(composeCorrection(adjustment: a).values),
    );
  });

  testWidgets('auto on warms an underwater dive photo once stats arrive', (
    tester,
  ) async {
    await pump(tester, item(), diverAuto: true);
    final stats = ChannelStats.fromRgba(blueRgba())!;
    expect(
      filter(tester)!.colorFilter,
      ColorFilter.matrix(
        computeAutoCorrection(stats, depthMeters: 18).toMatrix().values,
      ),
    );
  });

  testWidgets('a surface shot is left alone with auto on', (tester) async {
    await pump(
      tester,
      item(confidence: MatchConfidence.estimated, offset: -120),
      diverAuto: true,
    );
    expect(filter(tester), isNull);
  });

  group('a dive photo shown without its enrichment (library rows)', () {
    MediaEnrichment stored({
      required double depth,
      MatchConfidence confidence = MatchConfidence.interpolated,
      int? offset,
    }) => MediaEnrichment(
      id: 'e1',
      mediaId: 'm1',
      diveId: 'd1',
      depthMeters: depth,
      elapsedSeconds: 600,
      matchConfidence: confidence,
      timestampOffsetSeconds: offset,
      createdAt: DateTime.utc(2026),
    );

    testWidgets('a stored surface shot is still left alone', (tester) async {
      await pump(
        tester,
        item(depth: null),
        diverAuto: true,
        stored: stored(
          depth: 0.4,
          confidence: MatchConfidence.estimated,
          offset: 300,
        ),
      );
      expect(filter(tester), isNull);
    });

    testWidgets('the stored depth bounds the fix', (tester) async {
      await pump(
        tester,
        item(depth: null),
        diverAuto: true,
        stored: stored(depth: 5),
      );
      final stats = ChannelStats.fromRgba(blueRgba())!;
      expect(
        filter(tester)!.colorFilter,
        ColorFilter.matrix(
          computeAutoCorrection(stats, depthMeters: 5).toMatrix().values,
        ),
      );
    });
  });

  testWidgets('a lean video row builds its track with the stored match', (
    tester,
  ) async {
    final keys = <VideoTrackKey>[];
    final container = ProviderContainer(
      overrides: [
        diverAutoColorCorrectionProvider.overrideWithValue(true),
        colorAnalysisServiceProvider.overrideWithValue(
          ColorAnalysisService(decodeRgba: (_) async => blueRgba()),
        ),
        colorEnrichmentProvider.overrideWith(
          (ref, id) async => MediaEnrichment(
            id: 'e1',
            mediaId: 'm1',
            diveId: 'd1',
            depthMeters: 20,
            elapsedSeconds: 600,
            matchConfidence: MatchConfidence.interpolated,
            createdAt: DateTime.utc(2026),
          ),
        ),
        videoColorTrackProvider.overrideWith((ref, key) async {
          keys.add(key);
          return null;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ColorCorrected(
          item: item(type: MediaType.video, depth: null),
          analysisSource: source,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(keys.last.item.enrichment?.elapsedSeconds, 600);
  });

  testWidgets('media on no dive is left alone with auto on', (tester) async {
    await pump(tester, item(diveId: null), diverAuto: true);
    expect(filter(tester), isNull);
  });

  testWidgets('holding the original removes the correction', (tester) async {
    final container = await pump(
      tester,
      item(adjustment: const ColorAdjustment(warmth: 0.5)),
    );
    container.read(colorPeekOriginalNotifierProvider.notifier).peek('m1');
    await tester.pump();
    expect(filter(tester), isNull);
    container.read(colorPeekOriginalNotifierProvider.notifier).release();
    await tester.pump();
    expect(filter(tester), isNotNull);
  });

  testWidgets('a draft is drawn live', (tester) async {
    final container = await pump(tester, item());
    const draft = ColorAdjustment(tint: -0.5);
    container
        .read(colorAdjustmentDraftNotifierProvider('m1').notifier)
        .set(draft);
    await tester.pump();
    expect(
      filter(tester)!.colorFilter,
      ColorFilter.matrix(composeCorrection(adjustment: draft).values),
    );
  });

  testWidgets('a video tile uses its track average when it has one', (
    tester,
  ) async {
    const params = AutoCorrectionParams(
      redFromGreen: 0.2,
      gainR: 1.5,
      gainG: 1,
      gainB: 0.9,
    );
    await pump(
      tester,
      item(type: MediaType.video),
      diverAuto: true,
      track: const VideoColorTrack([VideoColorKey(seconds: 1, params: params)]),
    );
    expect(
      filter(tester)!.colorFilter,
      ColorFilter.matrix(params.toMatrix().values),
    );
  });
}
