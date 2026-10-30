import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/color/video_color_track.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/video_share_timeline.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/video_color_track_provider.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';

final _blue = Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(20, 100, 160)),
  ),
);
final _blueRgba = Uint8List.fromList([
  for (var i = 0; i < 64; i++) ...[20, 100, 160, 255],
]);

MediaEnrichment _enrichment({double depth = 18}) => MediaEnrichment(
  id: 'e1',
  mediaId: 'm1',
  diveId: 'd1',
  depthMeters: depth,
  elapsedSeconds: 600,
  matchConfidence: MatchConfidence.interpolated,
  createdAt: DateTime.utc(2026),
);

MediaItem video({
  ColorAdjustment? adjustment,
  bool lean = false,
  MediaType type = MediaType.video,
}) => MediaItem(
  id: 'm1',
  diveId: 'd1',
  mediaType: type,
  sourceType: MediaSourceType.platformGallery,
  originalFilename: 'reef.mov',
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  durationSeconds: 20,
  colorAdjustment: adjustment,
  enrichment: lean ? null : _enrichment(),
);

const _track = VideoColorTrack([
  VideoColorKey(
    seconds: 2,
    params: AutoCorrectionParams(
      redFromGreen: 0.3,
      gainR: 1.8,
      gainG: 1,
      gainB: 0.85,
    ),
  ),
  VideoColorKey(
    seconds: 18,
    params: AutoCorrectionParams(
      redFromGreen: 0.5,
      gainR: 2.4,
      gainG: 1,
      gainB: 0.75,
    ),
  ),
]);

class _StoredEnrichment implements MediaColorAdjustmentRepository {
  _StoredEnrichment(this.stored);
  final MediaEnrichment? stored;
  final asked = <String>[];

  @override
  Future<MediaEnrichment?> enrichmentFor(String mediaId) async {
    asked.add(mediaId);
    return stored;
  }

  @override
  Stream<void> watchEnrichmentChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Issue #3521: the colour timeline a shared video carries is the viewer's.
void main() {
  Future<T> withRef<T>(
    WidgetTester tester,
    Future<T> Function(WidgetRef ref) body, {
    bool diverAuto = false,
    VideoColorTrack? track = _track,
    double? Function(double)? depthAt,
    MediaEnrichment? stored,
    ColorAnalysisService? analysis,
    ResolvedAssetResult? poster,
    ColorAdjustment? draft,
    _StoredEnrichment? repository,
  }) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diverAutoColorCorrectionProvider.overrideWithValue(diverAuto),
          mediaColorAdjustmentRepositoryProvider.overrideWithValue(
            repository ?? _StoredEnrichment(stored),
          ),
          colorAnalysisServiceProvider.overrideWithValue(
            analysis ??
                ColorAnalysisService(decodeRgba: (_) async => _blueRgba),
          ),
          videoColorTrackProvider.overrideWith((ref, key) async => track),
          videoDepthAtProvider.overrideWith(
            (ref, key) async => depthAt ?? (double _) => 18.0,
          ),
          resolvedThumbnailProvider.overrideWith(
            (ref, item) async =>
                poster ??
                const ResolvedAssetResult(status: ResolutionStatus.unavailable),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    if (draft != null) {
      widgetRef
          .read(colorAdjustmentDraftNotifierProvider('m1').notifier)
          .set(draft);
    }
    return (await tester.runAsync(() => body(widgetRef))) as T;
  }

  testWidgets('photo gives null', (tester) async {
    final t = await withRef(
      tester,
      (ref) => videoShareTimelineFor(
        ref,
        video(
          type: MediaType.photo,
          adjustment: const ColorAdjustment(warmth: 1),
        ),
        path: '/v.mov',
      ),
    );
    expect(t, isNull);
  });

  testWidgets('no adjustment and auto off gives null', (tester) async {
    final t = await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(), path: '/v.mov'),
    );
    expect(t, isNull);
  });

  testWidgets('sliders only give one constant key', (tester) async {
    const a = ColorAdjustment(warmth: 0.5);
    final t = (await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(adjustment: a), path: '/v.mov'),
    ))!;
    expect(t.keys, hasLength(1));
    expect(t.keys.single.matrix, composeCorrection(adjustment: a).values);
  });

  testWidgets('auto with a track follows the track and depth', (tester) async {
    double depth(double s) => s < 10 ? 2 : 20;
    final t = (await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(), path: '/v.mov'),
      diverAuto: true,
      depthAt: depth,
    ))!;
    expect(t.keys.length, greaterThan(1));
    for (final s in [0.0, 5.0, 12.0, 20.0]) {
      final want = composeCorrection(
        adjustment: null,
        auto: _track.paramsAt(s, depthAt: depth),
      );
      expect(t.matrixAt((s * 1000).round()), want.values, reason: 'at $s s');
    }
  });

  testWidgets('the unsaved draft wins over the stored adjustment', (
    tester,
  ) async {
    const draft = ColorAdjustment(tint: -0.4);
    final t = (await withRef(
      tester,
      (ref) => videoShareTimelineFor(
        ref,
        video(adjustment: const ColorAdjustment(warmth: 1)),
        path: '/v.mov',
      ),
      draft: draft,
    ))!;
    expect(t.keys.single.matrix, composeCorrection(adjustment: draft).values);
  });

  testWidgets('a library row without enrichment reads the stored match', (
    tester,
  ) async {
    final repository = _StoredEnrichment(_enrichment());
    final t = await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(lean: true), path: '/v.mov'),
      diverAuto: true,
      repository: repository,
    );
    expect(repository.asked, ['m1']);
    expect(t, isNotNull);
  });

  testWidgets('no track falls back to cached poster stats', (tester) async {
    final analysis = ColorAnalysisService(decodeRgba: (_) async => _blueRgba);
    final item = video();
    await analysis.statsFor(colorStatsKey(item), MemoryImage(_blue));
    final t = (await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, item, path: '/v.mov'),
      diverAuto: true,
      track: null,
      analysis: analysis,
    ))!;
    final want = composeCorrection(
      adjustment: null,
      auto: autoParamsForPhoto(item, ChannelStats.fromRgba(_blueRgba)),
    );
    expect(t.keys.single.matrix, want.values);
  });

  testWidgets('no track and no cached stats analyses the poster thumbnail', (
    tester,
  ) async {
    final t = await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(), path: '/v.mov'),
      diverAuto: true,
      track: null,
      poster: ResolvedAssetResult(
        bytes: _blue,
        status: ResolutionStatus.resolved,
      ),
    );
    expect(t, isNotNull);
  });

  testWidgets('no track and no poster leaves the auto part out', (
    tester,
  ) async {
    final t = await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(), path: '/v.mov'),
      diverAuto: true,
      track: null,
    );
    expect(t, isNull);
  });

  testWidgets('surface clip with auto only gives null', (tester) async {
    final t = await withRef(
      tester,
      (ref) => videoShareTimelineFor(ref, video(), path: '/v.mov'),
      diverAuto: true,
      depthAt: (_) => 0,
    );
    expect(t, isNull);
  });

  testWidgets('videoMayNeedCorrection: sliders or auto on a video', (
    tester,
  ) async {
    final results = await withRef(
      tester,
      (ref) async => [
        videoMayNeedCorrection(ref, video()),
        videoMayNeedCorrection(
          ref,
          video(adjustment: const ColorAdjustment(warmth: 0.2)),
        ),
        videoMayNeedCorrection(
          ref,
          video(
            type: MediaType.photo,
            adjustment: const ColorAdjustment(warmth: 0.2),
          ),
        ),
      ],
    );
    expect(results, [false, true, false]);
    final withAuto = await withRef(
      tester,
      (ref) async => videoMayNeedCorrection(ref, video()),
      diverAuto: true,
    );
    expect(withAuto, isTrue);
  });
}
