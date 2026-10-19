import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/services/color_analysis_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Display-time colour correction wiring (issue #3520).

final colorAnalysisServiceProvider = Provider<ColorAnalysisService>(
  (ref) => ColorAnalysisService(),
);

final mediaColorAdjustmentRepositoryProvider =
    Provider<MediaColorAdjustmentRepository>(
      (ref) => MediaColorAdjustmentRepository(),
    );

/// [mediaId]'s stored profile match, for tiles whose row came without it.
final colorEnrichmentProvider = FutureProvider.autoDispose
    .family<MediaEnrichment?, String>((ref, mediaId) {
      // Enrichment is written by re-matching and sync pulls, outside any
      // notifier; the media tick covers the media_enrichment table.
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      return ref
          .watch(mediaColorAdjustmentRepositoryProvider)
          .enrichmentFor(mediaId);
    });

/// The diver's "Automatic color correction" switch.
final diverAutoColorCorrectionProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.autoColorCorrection)),
);

/// The adjustment being dragged in the panel for one media id, drawn live
/// before it is saved. Null when nothing is being edited.
final colorAdjustmentDraftProvider =
    NotifierProvider.family<ColorAdjustmentDraft, ColorAdjustment?, String>(
      ColorAdjustmentDraft.new,
    );

class ColorAdjustmentDraft extends Notifier<ColorAdjustment?> {
  ColorAdjustmentDraft(this.mediaId);

  final String mediaId;

  @override
  ColorAdjustment? build() => null;

  void set(ColorAdjustment? adjustment) => state = adjustment;

  void clear() => state = null;
}

/// The media id whose original is being shown while the diver holds the
/// photo (or the Original chip); it draws with no correction.
final colorPeekOriginalProvider = NotifierProvider<ColorPeekOriginal, String?>(
  ColorPeekOriginal.new,
);

class ColorPeekOriginal extends Notifier<String?> {
  @override
  String? build() => null;

  void peek(String mediaId) => state = mediaId;

  void release() => state = null;
}

/// What to draw [item] with: the live draft, else the stored adjustment.
ColorAdjustment? effectiveAdjustment(WidgetRef ref, MediaItem item) =>
    ref.watch(colorAdjustmentDraftProvider(item.id)) ?? item.colorAdjustment;

/// Cache key for an item's colour statistics: the item and where its pixels
/// come from, so relinking the file re-analyses it but saving an adjustment
/// (which bumps updatedAt) does not.
String colorStatsKey(MediaItem item) =>
    '${item.id}|${item.filePath}|${item.localPath}|${item.platformAssetId}';
