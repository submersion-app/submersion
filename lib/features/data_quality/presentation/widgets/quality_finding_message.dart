import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart'
    show GasMix;
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class QualityUnitFormatters {
  const QualityUnitFormatters({
    required this.depth,
    required this.depthRate,
    required this.pressure,
    required this.temperature,
    required this.temperatureDelta,
    required this.sac,
    required this.date,
    required this.dateTime,
    required this.limitDepth,
    required this.time,
  });
  final String Function(double meters) depth;

  /// Formats a vertical rate given in m/min, including the rate unit.
  final String Function(double metersPerMinute) depthRate;

  /// Formats a limit depth such as a MOD, rounded DOWN so it never reads
  /// deeper than the gas may be taken. Required, so no formatter set can
  /// silently round a limit to nearest.
  final String Function(double meters) limitDepth;
  final String Function(double bar) pressure;
  final String Function(double celsius) temperature;

  /// Formats a temperature DIFFERENCE given in Celsius. Not [temperature]:
  /// a difference scales without the offset a reading's conversion adds, so
  /// a 3 C jump reads 5.4 F, never 37.4 F (issue #4209).
  final String Function(double celsiusDelta) temperatureDelta;

  /// Formats an RMV given in L/min into the diver's preferred volume unit
  /// (L/min vs cuft/min), including the unit suffix.
  final String Function(double litersPerMin) sac;

  /// Formats a (UTC) calendar date in the diver's configured date-format
  /// preference, so a clock finding reads "01/06/1900" or "1900-06-01" to
  /// match the rest of the app instead of an ISO timestamp.
  final String Function(DateTime date) date;

  /// Formats a calendar date together with its clock time, in the diver's
  /// date-format and 12h/24h preferences. Identifying a dive needs the time
  /// as well as the day: repetitive dives share a date, and the findings that
  /// pair two of them are exactly the ones minutes apart.
  final String Function(DateTime dateTime) dateTime;

  /// Formats a clock time alone in the diver's 12h/24h preference, for a
  /// finding that already names the day (issue #2853).
  final String Function(DateTime time) time;
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
      'missing_gas_switch' => l10n.dataQuality_detector_missing_gas_switch,
      'transmitter_role' => l10n.dataQuality_detector_transmitter_role,
      'unknown_transmitter' => l10n.dataQuality_detector_unknown_transmitter,
      'transmitter_gear_serial_mismatch' =>
        l10n.dataQuality_detector_transmitter_gear_serial_mismatch,
      'source_conflict' => l10n.dataQuality_detector_source_conflict,
      'shared_gear_overlap' => l10n.dataQuality_detector_shared_gear_overlap,
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
  // Absent on gas findings stored before the detector recorded helium.
  final he = (p['hePercent'] as num?)?.toDouble();

  final title = detectorTitle(l10n, f.detectorId);
  String detail;
  switch (f.detectorId) {
    case 'clock_offset':
      if (p.containsKey('offsetHours')) {
        // The secondary source reads `offsetHours` later than the primary, so
        // a positive offset is a clock running ahead.
        final hours = i('offsetHours');
        detail = hours < 0
            ? l10n.dataQuality_msg_clock_offsetBehind(-hours)
            : l10n.dataQuality_msg_clock_offsetAhead(hours);
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
        qualityDurationLabel(l10n, i('longestGapSeconds')),
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
        fmt.depthRate(d('maxRateMetersPerMinute')),
        qualityDurationLabel(l10n, i('durationSeconds')),
      );
    case 'temp_anomaly':
      if (p.containsKey('deltaC')) {
        detail = l10n.dataQuality_msg_tempJump(
          fmt.temperatureDelta(d('deltaC')),
        );
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
      } else if (p.containsKey('mixedSources')) {
        detail = l10n.dataQuality_msg_pressureMixed;
      } else if (p.containsKey('dropoutCount')) {
        detail = l10n.dataQuality_msg_pressureDropout(
          (p['dropoutCount'] as num?)?.toInt() ?? 1,
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
          qualityGasLabel(l10n, d('o2Percent'), he),
          fmt.depth(d('depthAtPeak')),
        );
      } else if (p.containsKey('switchDepth')) {
        detail = l10n.dataQuality_msg_switchMod(
          fmt.depth(d('switchDepth')),
          fmt.limitDepth(d('modMeters')),
        );
      } else {
        detail = l10n.dataQuality_msg_hypoxic(
          qualityGasLabel(l10n, d('o2Percent'), he),
        );
      }
    case 'unknown_transmitter':
      detail = l10n.dataQuality_msg_unknownTransmitter(
        (p['serial'] as String?) ?? '',
      );
    case 'transmitter_gear_serial_mismatch':
      detail = l10n.dataQuality_msg_transmitterGearSerialMismatch(
        (p['serial'] as String?) ?? '',
      );
    case 'missing_gas_switch':
      detail = _missingSwitchDetail(l10n, p, fmt);
    case 'tank_assignment':
      detail = p.containsKey('inactiveDropBar')
          ? l10n.dataQuality_msg_tankInactive(
              fmt.pressure(d('inactiveDropBar')),
            )
          : l10n.dataQuality_msg_twinTanks;
    case 'transmitter_role':
      final role = TankRole.values.asNameMap()[p['role']];
      detail = l10n.dataQuality_msg_transmitterRoleBailout(
        i('tankPosition') + 1,
        role?.localizedName(l10n) ?? '',
        fmt.pressure(d('ocDropBar')),
      );
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
        detail = l10n.dataQuality_msg_sourceDuration(
          qualityDurationLabel(l10n, i('primarySeconds')),
          qualityDurationLabel(l10n, i('sourceSeconds')),
        );
      } else {
        detail = l10n.dataQuality_msg_sourceTemp(
          fmt.temperature(d('primaryTempC')),
          fmt.temperature(d('sourceTempC')),
        );
      }
    case 'shared_gear_overlap':
      detail = _sharedGearDetail(l10n, p, fmt);
    default:
      detail = '';
  }
  return QualityFindingMessage(title: title, detail: detail);
}

/// A duration in a finding message: seconds while that is the natural unit,
/// whole minutes from two minutes on, so a 1620 s run reads "27 min".
String qualityDurationLabel(AppLocalizations l10n, int seconds) => seconds < 120
    ? l10n.dataQuality_unit_seconds(seconds)
    : l10n.dataQuality_unit_minutes((seconds / 60).round());

/// The missing-switch finding's text (issue #165): every switch it offers,
/// then every start it held back for being deeper than its gas's MOD.
String _missingSwitchDetail(
  AppLocalizations l10n,
  Map<String, Object?> p,
  QualityUnitFormatters fmt,
) {
  List<Map<String, Object?>> entries(String key) => [
    if (p[key] case final List list)
      for (final e in list)
        if (e is Map) e.cast<String, Object?>(),
  ];
  double d(Map<String, Object?> e, String k) => (e[k] as num?)?.toDouble() ?? 0;
  // Stored 0-based, as the transmitter role finding's is.
  int number(Map<String, Object?> e) =>
      ((e['tankPosition'] as num?)?.toInt() ?? 0) + 1;
  String gas(Map<String, Object?> e) => qualityGasLabel(
    l10n,
    d(e, 'o2Percent'),
    (e['hePercent'] as num?)?.toDouble(),
  );

  final switches = entries('missingSwitches');
  final deep = entries('deepStarts');
  final sentences = <String>[
    if (switches.isNotEmpty)
      l10n.dataQuality_msg_missingSwitches(
        switches.length,
        switches
            .map(
              (e) => l10n.dataQuality_msg_missingSwitchItem(
                number(e),
                gas(e),
                formatMinutesSeconds((e['t'] as num?)?.toInt() ?? 0),
                fmt.depth(d(e, 'depth')),
              ),
            )
            .join(l10n.dataQuality_msg_missingSwitchSeparator),
      ),
    // Every too-deep start, the first opening the message when no switch
    // can be offered.
    for (final (i, e) in deep.indexed)
      (i == 0 && switches.isEmpty
          ? l10n.dataQuality_msg_missingSwitchDeep
          : l10n.dataQuality_msg_missingSwitchDeepAlso)(
        number(e),
        gas(e),
        fmt.depth(d(e, 'depth')),
        fmt.limitDepth(d(e, 'modMeters')),
      ),
  ];
  return sentences.join(' ');
}

/// The mix a gas finding names. Air and oxygen are words and translate;
/// nitrox and trimix keep their international notation (EAN32, Tx 18/45),
/// so a trimix keeps its helium instead of reading as nitrox (issue #4209).
///
/// A null [hePercent] is a finding stored before the detector recorded it.
/// Its helium is unknown, so it names the oxygen share alone rather than
/// calling a Tx 21/35 "Air"; the next scan rewrites it.
String qualityGasLabel(
  AppLocalizations l10n,
  double o2Percent,
  double? hePercent,
) {
  if (hePercent == null) return '${o2Percent.round()}% O2';
  final mix = GasMix(o2: o2Percent, he: hePercent);
  if (mix.isAir) return l10n.gas_air_displayName;
  if (mix.isOxygen) return l10n.gas_oxygen_displayName;
  return mix.name;
}

/// "{item} is on {diverA}'s dive at {timeA} and {diverB}'s dive at
/// {timeB}." in the params' dive order (ascending dive id, so the same on
/// every device), plus the installed parts (issue #2853). Entry times are
/// UTC wall-clock instants, rebuilt with isUtc so they format as recorded.
String _sharedGearDetail(
  AppLocalizations l10n,
  Map<String, Object?> p,
  QualityUnitFormatters fmt,
) {
  final dives = p['dives'];
  final sides = dives is Map
      ? [
          for (final s in dives.values)
            if (s is Map) s,
        ]
      : const <Map>[];
  if (sides.length != 2) return '';
  String name(Map s) {
    final n = s['diverName'];
    return n is String && n.isNotEmpty ? n : l10n.sharedItems_ownerUnknown;
  }

  String time(Map s) => fmt.time(
    DateTime.fromMillisecondsSinceEpoch(
      (s['entryMs'] as num?)?.toInt() ?? 0,
      isUtc: true,
    ),
  );

  var detail = l10n.dataQuality_msg_shared_gear_overlap(
    p['itemName'] as String? ?? '',
    name(sides[0]),
    time(sides[0]),
    name(sides[1]),
    time(sides[1]),
  );
  final parts = (p['partIds'] as List?)?.length ?? 0;
  if (parts > 0) {
    detail = '$detail ${l10n.dataQuality_msg_shared_gear_overlap_parts(parts)}';
  }
  return detail;
}
