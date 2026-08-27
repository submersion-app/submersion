import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One line of the dive readout: a localized label and a unit-formatted
/// value. [emphasized] marks the row of the metric on the Z axis.
class ReadoutRow {
  final String label;
  final String value;
  final bool emphasized;
  const ReadoutRow(this.label, this.value, {this.emphasized = false});
}

/// The interpolation lookups one dive's readout needs, built once and
/// reused. [ProfileLookupOverPressure] copies each tank series into flat
/// arrays, so constructing these inside a frame-rate builder would allocate
/// on every playback tick; hold one of these per [Dive3dSceneData] instead
/// and hand it to the readout panel, the hover tooltip, and the marker
/// sheet alike.
class DiveReadoutLookups {
  final Dive3dSceneData data;
  final ProfileLookup profile;

  /// The nullable views the interpolator needs. `cast` allocates a wrapper
  /// and [Dive3dSceneData.ttsSeconds] rebuilds the whole series, so both are
  /// held here rather than re-derived on every tick.
  final List<double?> depths;
  final List<double?> ttsSeconds;

  /// One entry per tank in [Dive3dSceneData.tankPressures] order; null where
  /// that tank logged no pressure samples.
  final List<ProfileLookupOverPressure?> tankPressure;

  DiveReadoutLookups(this.data)
    : profile = ProfileLookup(data.times),
      depths = data.depths.cast<double?>(),
      ttsSeconds = data.ttsSeconds,
      tankPressure = [
        for (final points in data.tankPressures.values)
          if (points.isEmpty) null else ProfileLookupOverPressure(points),
      ];
}

/// The single source of truth for what the tooltip, the scrub readout
/// panel, and the marker sheet show at an instant. Interpolates the
/// FULL-resolution series so geometry decimation never affects readouts.
List<ReadoutRow> diveReadoutRows({
  required DiveReadoutLookups lookups,
  required double timestampSeconds,
  required UnitFormatter units,
  required AppLocalizations l10n,
  SceneMetric? emphasize,
}) {
  final data = lookups.data;
  final t = timestampSeconds;
  double? at(List<double?> series) => lookups.profile.interpolate(series, t);
  final total = t.round();
  final clock = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';

  final rows = <ReadoutRow>[ReadoutRow(l10n.dive3d_readout_runTime, clock)];
  void add(SceneMetric? metric, String label, String? value) {
    if (value == null) return;
    rows.add(
      ReadoutRow(
        label,
        value,
        emphasized: metric != null && metric == emphasize,
      ),
    );
  }

  final depth = at(lookups.depths);
  add(
    SceneMetric.depth,
    l10n.dive3d_metric_depth,
    depth == null ? null : units.formatDepth(depth),
  );
  final temp = at(data.temperatures);
  add(
    SceneMetric.temperature,
    l10n.dive3d_metric_temperature,
    temp == null ? null : units.formatTemperature(temp),
  );
  final rate = at(data.ascentRates);
  add(
    SceneMetric.ascentRate,
    l10n.dive3d_metric_ascentRate,
    rate == null
        ? null
        : '${units.convertDepth(rate).toStringAsFixed(1)} '
              '${units.depthSymbol}/min',
  );
  final ppO2 = at(data.ppO2s);
  add(SceneMetric.ppO2, l10n.dive3d_metric_ppO2, ppO2?.toStringAsFixed(2));
  final cns = at(data.cnss);
  add(
    SceneMetric.cns,
    l10n.dive3d_metric_cns,
    cns == null ? null : '${cns.round()}%',
  );
  final hr = at(data.heartRates);
  add(
    SceneMetric.heartRate,
    l10n.dive3d_metric_heartRate,
    hr == null ? null : '${hr.round()} bpm',
  );
  final ceiling = at(data.ceilings);
  add(
    null,
    l10n.dive3d_readout_ceiling,
    ceiling == null || ceiling <= 0 ? null : units.formatDepth(ceiling),
  );
  final tts = at(lookups.ttsSeconds);
  add(
    SceneMetric.tts,
    l10n.dive3d_metric_tts,
    tts == null ? null : '${(tts / 60).round()} min',
  );
  for (var i = 0; i < lookups.tankPressure.length; i++) {
    final bar = lookups.tankPressure[i]?.at(t);
    add(
      SceneMetric.tankPressure,
      l10n.dive3d_readout_tank(i + 1),
      bar == null ? null : units.formatPressure(bar),
    );
  }
  return rows;
}
