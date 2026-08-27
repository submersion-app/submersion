import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Colour key for the active track colorization mode.
///
/// Renders nothing in uniform mode - a single-colour line needs no legend.
class TrackColorLegend extends ConsumerWidget {
  const TrackColorLegend({super.key, required this.mode, this.speedRangeMps});

  final TrackColorMode mode;
  final ({double min, double max})? speedRangeMps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mode == TrackColorMode.uniform) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = trackBucketColors(
      theme.colorScheme,
      mode,
      kTrackColorBuckets,
    );

    final String lowLabel;
    final String highLabel;
    if (mode == TrackColorMode.speed) {
      final range = speedRangeMps;
      if (range == null) {
        lowLabel = l10n.gpsTrack_legend_slower;
        highLabel = l10n.gpsTrack_legend_faster;
      } else {
        final units = UnitFormatter(ref.watch(settingsProvider));
        lowLabel = units.formatSpeed(range.min);
        highLabel = units.formatSpeed(range.max);
      }
    } else {
      lowLabel = l10n.gpsTrack_legend_start;
      highLabel = l10n.gpsTrack_legend_end;
    }

    return Card(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // The ramp stretches to whatever width the labels need rather than
        // the labels being clipped to a fixed ramp width: a formatted speed
        // pair ("0.0 km/h" / "36.0 km/h") is wider than eight 16px swatches.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 128),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const ValueKey('track-legend-ramp'),
                  height: 10,
                  child: Row(
                    children: [
                      for (final color in colors)
                        Expanded(child: ColoredBox(color: color)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lowLabel, style: theme.textTheme.labelSmall),
                    const SizedBox(width: 12),
                    Text(highLabel, style: theme.textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
