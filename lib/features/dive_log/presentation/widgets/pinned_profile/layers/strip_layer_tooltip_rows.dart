import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gtr_format.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_phase_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/pinned_strip_layer_animator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The pinned strip's tooltip rows for its active card layers at
/// [cursorSeconds] (issue #4562), after its own rows: each value as the full
/// chart's tooltip or the card reads it, in the diver's units, in layer
/// order. A layer with no value at the cursor adds no row, nor do the marks
/// (media, annotations, bookmarks, gas switches), which carry no value.
/// [sacRow] reads a SAC rate (bar/min at the surface) as the diver's chosen
/// gas consumption display; without it the row is SAC.
List<TooltipRow> stripLayerTooltipRows({
  required StripLayerState layers,
  required int cursorSeconds,
  int? cursorIndex,
  required UnitFormatter units,
  required AppLocalizations l10n,
  ({String label, String value}) Function(double sacBarPerMin)? sacRow,
}) {
  final data = layers.data;
  final s = cursorSeconds;
  final minutes = l10n.units_profileMetric_min;

  List<TooltipRow> lines(StripLayer layer, String Function(double v) format) =>
      [
        for (final line in data.lines)
          if (line.layer == layer)
            if (line.valueAt(s, index: cursorIndex) case final v?)
              TooltipRow(
                label: line.label == null
                    ? _labelOf(layer, l10n)
                    : line.estimated
                    ? '${line.label} ${l10n.diveLog_pressure_estimatedSuffix}'
                    : line.label!,
                value: format(v),
                bulletColor: line.color,
              ),
      ];

  List<TooltipRow> rowsOf(StripLayer layer) => switch (layer) {
    StripLayer.temperature => lines(layer, units.formatTemperature),
    StripLayer.cns => lines(layer, (v) => '${v.toStringAsFixed(1)}%'),
    StripLayer.surfaceGf => lines(layer, (v) => '${v.toStringAsFixed(0)}%'),
    StripLayer.tankPressure => lines(layer, units.formatPressure),
    StripLayer.gtr => lines(
      layer,
      (v) => formatGtrMinutes(v.round(), minuteUnit: minutes),
    ),
    // As the full chart reads it: SAC, or RMV when the diver shows only
    // that ([sacRow], from `gasConsumptionTooltipRow`).
    StripLayer.sac => [
      for (final line in data.lines)
        if (line.layer == layer)
          if (line.valueAt(s, index: cursorIndex) case final v?)
            if (sacRow?.call(v) case final row?)
              TooltipRow(
                label: row.label,
                value: row.value,
                bulletColor: line.color,
              )
            else
              TooltipRow(
                label: l10n.gasConsumption_sac,
                value: units.formatSac(v),
                bulletColor: line.color,
              ),
    ],
    StripLayer.tts => lines(layer, (v) => '${(v / 60).ceil()} $minutes'),
    StripLayer.heartRate => lines(
      layer,
      (v) => '${v.round()} ${l10n.units_profileMetric_bpm}',
    ),
    StripLayer.phases => [
      if (_phaseAt(data, s) case final band?)
        TooltipRow(
          label: l10n.diveLog_detail_sacSegments_phase,
          value: divePhaseLabel(band.phase!, l10n),
          bulletColor: band.color,
        ),
    ],
    StripLayer.safetyFindings => [
      for (final band in data.bands)
        if (band.layer == layer && band.start <= s && s <= band.end)
          if (band.finding case final finding?)
            TooltipRow(
              label: l10n.safetyReview_sectionTitle,
              value: safetyRuleLabel(finding.ruleId, l10n),
              bulletColor: band.color,
            ),
    ],
    StripLayer.plannedDepth || StripLayer.sourceDepths => [
      for (final ghost in data.ghosts)
        if (ghost.layer == layer)
          if (ghost.depthAt(s) case final depth?)
            TooltipRow(
              label: '${l10n.diveLog_tooltip_depth} · ${ghost.label}',
              value: units.formatDepth(depth),
              bulletColor: ghost.color,
            ),
    ],
    StripLayer.gasSwitches ||
    StripLayer.media ||
    StripLayer.annotations => const [],
  };

  return [
    for (final layer in StripLayer.values)
      if (layers.active.contains(layer)) ...rowsOf(layer),
  ];
}

/// The phase band under [seconds]: the one it falls in, the later of two
/// it joins, or at the very end of the dive the one that ends there.
StripBand? _phaseAt(PinnedStripLayerData data, int seconds) {
  StripBand? endingHere;
  for (final band in data.bands) {
    if (band.layer != StripLayer.phases || band.phase == null) continue;
    if (band.start <= seconds && seconds < band.end) return band;
    if (band.end == seconds) endingHere = band;
  }
  return endingHere;
}

/// The tooltip label of a layer with one line.
String _labelOf(StripLayer layer, AppLocalizations l10n) => switch (layer) {
  StripLayer.temperature => l10n.diveLog_tooltip_temp,
  StripLayer.cns => l10n.diveLog_tooltip_cns,
  StripLayer.surfaceGf => l10n.diveLog_tooltip_srfGf,
  StripLayer.gtr => l10n.diveLog_tooltip_gtr,
  StripLayer.sac => l10n.gasConsumption_sac,
  StripLayer.tts => l10n.diveLog_tooltip_tts,
  StripLayer.heartRate => l10n.diveLog_tooltip_hr,
  _ => layer.name,
};
