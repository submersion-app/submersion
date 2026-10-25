import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One line of the track readout: a localized label and a unit-formatted
/// value. [emphasized] marks the row of the metric on the Z axis, as
/// `ReadoutRow` does for a dive.
class TrackReadoutRow {
  final String label;
  final String value;
  final bool emphasized;
  const TrackReadoutRow(this.label, this.value, {this.emphasized = false});
}

/// The interpolation lookup a track's readout needs, built once per scene
/// and reused across the panel, playback ticks, and (if added later) a
/// hover tooltip -- mirrors [DiveReadoutLookups] for the same reason: the
/// profile is full-resolution even when the geometry is decimated.
class TrackReadoutLookups {
  final NavTrack3dSceneData data;
  final ProfileLookup profile;

  /// The nullable view of [NavTrack3dSceneData.depths] the interpolator
  /// needs. `cast` allocates a wrapper, so it is held here rather than
  /// re-derived on every playback tick.
  final List<double?> depths;

  TrackReadoutLookups(this.data)
    : profile = ProfileLookup(data.times),
      depths = data.depths.cast<double?>();
}

/// The single source of truth for what the track scrub readout shows at an
/// instant. Omits a row whose metric has no samples at all, mirroring
/// [NavTrack3dSceneData.availableMetrics].
List<TrackReadoutRow> trackReadoutRows({
  required TrackReadoutLookups lookups,
  required double timestampSeconds,
  required UnitFormatter units,
  required AppLocalizations l10n,
  TrackSceneMetric? emphasize,
}) {
  final data = lookups.data;
  final t = timestampSeconds;
  double? at(List<double?> series) => lookups.profile.interpolate(series, t);
  final total = t.round();
  final clock = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';

  final rows = <TrackReadoutRow>[
    TrackReadoutRow(l10n.dive3d_readout_runTime, clock),
  ];
  void add(TrackSceneMetric metric, String label, String? value) {
    if (value == null) return;
    rows.add(TrackReadoutRow(label, value, emphasized: metric == emphasize));
  }

  final depth = at(lookups.depths);
  add(
    TrackSceneMetric.depth,
    l10n.dive3d_metric_depth,
    depth == null ? null : units.formatDepth(depth),
  );
  final temp = at(data.temperatures);
  add(
    TrackSceneMetric.temperature,
    l10n.dive3d_metric_temperature,
    temp == null ? null : units.formatTemperature(temp),
  );
  final speed = at(data.speeds);
  add(
    TrackSceneMetric.speed,
    l10n.navTrack3d_metric_speed,
    speed == null ? null : units.formatTrackSpeed(speed),
  );
  final volts = at(data.batteryVolts);
  add(
    TrackSceneMetric.batteryVoltage,
    l10n.navTrack3d_metric_batteryVoltage,
    volts == null ? null : '${formatFixedForDisplay(volts, 2)} V',
  );
  return rows;
}

/// Live metric readout at the scrub instant, styled like
/// [SceneReadoutPanel] but over [TrackReadoutLookups]. Listens to the
/// frame-rate [ValueListenable] directly so playback never rebuilds the
/// page tree above it.
class TrackReadoutPanel extends ConsumerWidget {
  final TrackReadoutLookups lookups;
  final ValueListenable<double> position;
  final TrackSceneMetric? emphasize;

  const TrackReadoutPanel({
    super.key,
    required this.lookups,
    required this.position,
    this.emphasize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall;
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final rows = trackReadoutRows(
          lookups: lookups,
          timestampSeconds: value * lookups.data.durationSeconds,
          units: units,
          l10n: l10n,
          emphasize: emphasize,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final row in rows)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${row.label} ',
                        style: text?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        row.value,
                        style: text?.copyWith(
                          fontWeight: row.emphasized
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: row.emphasized ? scheme.primary : null,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
