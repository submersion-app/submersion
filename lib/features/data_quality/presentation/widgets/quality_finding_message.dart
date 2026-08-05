import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class QualityUnitFormatters {
  const QualityUnitFormatters({
    required this.depth,
    required this.pressure,
    required this.temperature,
    required this.sac,
    required this.date,
  });
  final String Function(double meters) depth;
  final String Function(double bar) pressure;
  final String Function(double celsius) temperature;

  /// Formats a surface air consumption rate given in L/min into the diver's
  /// preferred volume unit (L/min vs cuft/min), including the unit suffix.
  final String Function(double litersPerMin) sac;

  /// Formats a (UTC) calendar date in the diver's configured date-format
  /// preference, so a clock finding reads "01/06/1900" or "1900-06-01" to
  /// match the rest of the app instead of an ISO timestamp.
  final String Function(DateTime date) date;
}

class QualityFindingMessage {
  const QualityFindingMessage({required this.title, required this.detail});
  final String title;
  final String detail;
}

String detectorTitle(AppLocalizations l10n, String detectorId) =>
    switch (detectorId) {
      'clock_offset' => l10n.dataQuality_detector_clock_offset,
      'duplicate' => l10n.dataQuality_detector_duplicate,
      'split_pair' => l10n.dataQuality_detector_split_pair,
      'sample_gap' => l10n.dataQuality_detector_sample_gap,
      'depth_spike' => l10n.dataQuality_detector_depth_spike,
      'impossible_rate' => l10n.dataQuality_detector_impossible_rate,
      'temp_anomaly' => l10n.dataQuality_detector_temp_anomaly,
      'pressure_anomaly' => l10n.dataQuality_detector_pressure_anomaly,
      'gas_mod' => l10n.dataQuality_detector_gas_mod,
      'tank_assignment' => l10n.dataQuality_detector_tank_assignment,
      'source_conflict' => l10n.dataQuality_detector_source_conflict,
      _ => detectorId,
    };

/// Renders a finding's numeric params into localized copy. Facts in, prose
/// out -- the row itself never stores prose, so a finding synced from a
/// metric German desktop renders correctly on an imperial English phone.
QualityFindingMessage buildFindingMessage(
  AppLocalizations l10n,
  QualityFinding f,
  QualityUnitFormatters fmt,
) {
  final p = f.params;
  double d(String key) => (p[key] as num?)?.toDouble() ?? 0;
  int i(String key) => (p[key] as num?)?.toInt() ?? 0;

  final title = detectorTitle(l10n, f.detectorId);
  String detail;
  switch (f.detectorId) {
    case 'clock_offset':
      if (p.containsKey('offsetHours')) {
        detail = l10n.dataQuality_msg_clock_offset(i('offsetHours'));
      } else if (p.containsKey('overlapMinutes')) {
        detail = l10n.dataQuality_msg_clock_overlap(i('overlapMinutes'));
      } else {
        // Stored as UTC epoch millis; reconstruct with isUtc so the displayed
        // year/date and the ancient-vs-future split don't drift by timezone.
        // Render through the diver's date formatter (not an ISO timestamp);
        // the UTC calendar fields format as-is, preserving the stored
        // wall-clock.
        final date = DateTime.fromMillisecondsSinceEpoch(
          i('entryTimeMs'),
          isUtc: true,
        );
        final dateText = fmt.date(date);
        detail = date.year < 1950
            ? l10n.dataQuality_msg_clock_ancient(dateText)
            : l10n.dataQuality_msg_clock_future(dateText);
      }
    case 'duplicate':
      detail = l10n.dataQuality_msg_duplicate(
        (d('score') * 100).round(),
        i('timeDiffMinutes'),
      );
    case 'split_pair':
      detail = l10n.dataQuality_msg_split((i('gapSeconds') / 60).round());
    case 'sample_gap':
      detail = l10n.dataQuality_msg_gap(
        i('gapCount'),
        '${i('longestGapSeconds')} s',
      );
    case 'depth_spike':
      if (p.containsKey('storedMaxDepth')) {
        detail = l10n.dataQuality_msg_maxDepthMismatch(
          fmt.depth(d('storedMaxDepth')),
          fmt.depth(d('profileMaxDepth')),
        );
      } else if (p.containsKey('minDepth')) {
        detail = l10n.dataQuality_msg_negativeDepth(i('sampleCount'));
      } else {
        final at = i('atSeconds');
        detail = l10n.dataQuality_msg_spike(
          fmt.depth(d('depth')),
          '${at ~/ 60}:${(at % 60).toString().padLeft(2, '0')}',
        );
      }
    case 'impossible_rate':
      detail = l10n.dataQuality_msg_rate(
        '${fmt.depth(d('maxRateMetersPerMinute'))}/min',
        i('durationSeconds'),
      );
    case 'temp_anomaly':
      if (p.containsKey('deltaC')) {
        detail = l10n.dataQuality_msg_tempJump(fmt.temperature(d('deltaC')));
      } else if (p.containsKey('waterTempC')) {
        detail = l10n.dataQuality_msg_tempScalar(
          fmt.temperature(d('waterTempC')),
        );
      } else {
        detail = l10n.dataQuality_msg_tempRange(
          fmt.temperature(d('minTempC')),
          fmt.temperature(d('maxTempC')),
        );
        if (p['fahrenheitAsKelvinSuspected'] == true) {
          detail = '$detail ${l10n.dataQuality_msg_tempUnitBug}';
        }
      }
    case 'pressure_anomaly':
      if (p.containsKey('startBar') && p.containsKey('endBar')) {
        detail = l10n.dataQuality_msg_pressureSwap(
          fmt.pressure(d('endBar')),
          fmt.pressure(d('startBar')),
        );
      } else if (p.containsKey('recordBar')) {
        detail = l10n.dataQuality_msg_pressureEndpoint(
          fmt.pressure(d('recordBar')),
          fmt.pressure(d('seriesBar')),
        );
      } else if (p.containsKey('riseBar')) {
        detail = l10n.dataQuality_msg_pressureRise(fmt.pressure(d('riseBar')));
      } else {
        detail = l10n.dataQuality_msg_sac(fmt.sac(d('surfaceLpm')));
      }
    case 'gas_mod':
      if (p.containsKey('peakPpO2')) {
        detail = l10n.dataQuality_msg_ppo2(
          d('peakPpO2').toStringAsFixed(2),
          'EAN${d('o2Percent').round()}',
          fmt.depth(d('depthAtPeak')),
        );
      } else if (p.containsKey('switchDepth')) {
        detail = l10n.dataQuality_msg_switchMod(
          fmt.depth(d('switchDepth')),
          fmt.depth(d('modMeters')),
        );
      } else {
        detail = l10n.dataQuality_msg_hypoxic('${d('o2Percent').round()}%');
      }
    case 'tank_assignment':
      detail = p.containsKey('inactiveDropBar')
          ? l10n.dataQuality_msg_tankInactive(
              fmt.pressure(d('inactiveDropBar')),
            )
          : l10n.dataQuality_msg_twinTanks;
    case 'source_conflict':
      if (p.containsKey('primaryMaxDepth')) {
        detail = l10n.dataQuality_msg_sourceDepth(
          fmt.depth(d('primaryMaxDepth')),
          fmt.depth(d('sourceMaxDepth')),
        );
        if (p['salinitySettingSuspected'] == true) {
          detail = '$detail ${l10n.dataQuality_msg_salinityHint}';
        }
      } else if (p.containsKey('primarySeconds')) {
        detail = l10n.dataQuality_msg_sourceDuration;
      } else {
        detail = l10n.dataQuality_msg_sourceTemp;
      }
    default:
      detail = '';
  }
  return QualityFindingMessage(title: title, detail: detail);
}
