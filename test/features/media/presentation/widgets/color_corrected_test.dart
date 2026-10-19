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
import 'package:submersion/features/media/presentation/widgets/color_corrected.dart';

Uint8List blueRgba() => Uint8List.fromList([
  for (var i = 0; i < 64; i++) ...[20, 100, 160, 255],
]);

MediaItem item({
  String? diveId = 'd1',
  double? depth = 18,
  MatchConfidence confidence = MatchConfidence.interpolated,
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
  }) async {
    final container = ProviderContainer(
      overrides: [
        diverAutoColorCorrectionProvider.overrideWithValue(diverAuto),
        colorAnalysisServiceProvider.overrideWithValue(
          ColorAnalysisService(decodeRgba: (_) async => blueRgba()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ColorCorrected(
          item: item,
          analysisSource: source,
          track: track,
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
      item(confidence: MatchConfidence.estimated),
      diverAuto: true,
    );
    expect(filter(tester), isNull);
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
    container.read(colorPeekOriginalProvider.notifier).peek('m1');
    await tester.pump();
    expect(filter(tester), isNull);
    container.read(colorPeekOriginalProvider.notifier).release();
    await tester.pump();
    expect(filter(tester), isNotNull);
  });

  testWidgets('a draft is drawn live', (tester) async {
    final container = await pump(tester, item());
    const draft = ColorAdjustment(tint: -0.5);
    container.read(colorAdjustmentDraftProvider('m1').notifier).set(draft);
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
