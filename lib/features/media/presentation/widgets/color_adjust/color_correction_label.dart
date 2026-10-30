import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/media/domain/color/color_correction_policy.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small pill saying what colour correction [item] is drawn with (issue
/// #3520): "Adjusted" for a hand adjustment, "18m · auto" for the automatic
/// fix at a known depth, "Auto" without one, and nothing otherwise.
class ColorCorrectionLabel extends ConsumerWidget {
  const ColorCorrectionLabel({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final adjustment = effectiveAdjustment(ref, item);
    final handAdjusted =
        adjustment != null &&
        !adjustment.copyWith(autoOverride: null).isNeutral;
    final String? text;
    if (handAdjusted) {
      text = l10n.media_color_labelAdjusted;
    } else if (needsAutoStats(
          item,
          adjustment: adjustment,
          diverAutoEnabled: diverAutoFor(ref, item),
        ) &&
        _autoDrawn(ref, item)) {
      final depth = item.enrichment?.depthMeters;
      text = depth == null
          ? l10n.media_color_auto
          : l10n.media_color_labelAutoDepth(
              UnitFormatter(
                ref.watch(settingsProvider),
              ).formatDepth(depth, decimals: 0),
            );
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return _pill(context, text);
  }

  /// Whether the automatic fix actually changes [item] as drawn. A photo
  /// whose red survived (strobe-lit, a red subject), one with no depth that
  /// does not look underwater, or one not analysed yet is drawn unchanged,
  /// so it is not labelled. A video's fix follows the clip, so it is.
  static bool _autoDrawn(WidgetRef ref, MediaItem item) {
    if (item.isVideo) return true;
    final params = autoParamsForPhoto(
      item,
      ref.read(colorAnalysisServiceProvider).peek(colorStatsKey(item)),
    );
    return params != null && !params.toMatrix().isIdentity;
  }

  static Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
