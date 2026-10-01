import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/features/dive_computer/data/services/libdc_sample_units.dart';
import 'package:submersion/features/dive_computer/data/services/parsed_tank_resolver.dart';
import 'package:submersion/features/dive_log/domain/codecs/deco_type.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What [ParsedDiveProfileMapper.gasSwitches] returns: the dive's tank list,
/// with any appended cylinders, its gas switches, and its profile.
typedef ParsedGasSwitches = ({
  List<Map<String, dynamic>> tanks,
  List<Map<String, dynamic>> gasSwitches,
  List<Map<String, dynamic>> profile,
});

/// Converts a libdivecomputer [pigeon.ParsedDive] into the profile-sample
/// maps the import pipeline consumes.
///
/// Shared by every importer that reaches libdivecomputer with raw device
/// bytes: Shearwater Cloud (`ShearwaterDiveMapper`) and MacDive SQLite
/// (`MacDiveDiveMapper`), which recovers the same Shearwater byte stream from
/// `ZDIVE.ZRAWDATA`. Keeping one implementation means a newly supported
/// sensor channel lands for both sources at once.
class ParsedDiveProfileMapper {
  const ParsedDiveProfileMapper._();

  /// Builds the `profile` value: one map per sample, with every sensor
  /// channel libdivecomputer reported.
  static List<Map<String, dynamic>> samples(pigeon.ParsedDive parsed) {
    return parsed.samples.map((s) {
      final sampleMap = <String, dynamic>{
        'timestamp': s.timeSeconds,
        'depth': s.depthMeters,
      };
      if (s.temperatureCelsius != null) {
        sampleMap['temperature'] = s.temperatureCelsius;
      }
      if (s.pressureBar != null) {
        // Key must be `allTankPressures`; `_storeTankPressures` reads only
        // this one, and the singular `pressure` key is ignored downstream.
        sampleMap['allTankPressures'] = <Map<String, dynamic>>[
          {'pressure': s.pressureBar, 'tankIndex': s.tankIndex ?? 0},
        ];
      }
      if (s.setpoint != null) {
        sampleMap['setpoint'] = s.setpoint;
      }
      if (s.ppo2 != null) {
        sampleMap['ppO2'] = s.ppo2;
      }
      // Per-cell CCR ppO2. libdivecomputer reports DC_SAMPLE_PPO2 once per
      // cell plus optionally once for the aggregate, and the native callback
      // keeps them apart; carry both, as the download path does. A dive whose
      // computer logs cells but no aggregate has its loop value averaged from
      // these downstream (resolveRebreatherPpO2), so they must survive alone.
      final cells = <double?>[
        s.o2Sensor1,
        s.o2Sensor2,
        s.o2Sensor3,
        s.o2Sensor4,
        s.o2Sensor5,
        s.o2Sensor6,
      ];
      for (var cell = 0; cell < cells.length; cell++) {
        if (cells[cell] != null) {
          sampleMap['o2Sensor${cell + 1}'] = cells[cell];
        }
      }
      // Raw cell output, carried independently of the bar values above: a
      // computer with an untrusted calibration reports these and nothing else
      // (issue #810).
      final cellMv = <int?>[
        s.o2SensorMv1,
        s.o2SensorMv2,
        s.o2SensorMv3,
        s.o2SensorMv4,
        s.o2SensorMv5,
        s.o2SensorMv6,
      ];
      for (var cell = 0; cell < cellMv.length; cell++) {
        if (cellMv[cell] != null) {
          sampleMap['o2SensorMv${cell + 1}'] = cellMv[cell];
        }
      }
      if (s.heartRate != null) {
        sampleMap['heartRate'] = s.heartRate;
      }
      if (s.cns != null) {
        sampleMap['cns'] = s.cns;
      }
      if (s.rbt != null) {
        sampleMap['rbt'] = libdcRbtToSeconds(s.rbt);
      }
      if (s.tts != null) {
        sampleMap['tts'] = s.tts;
      }
      if (s.decoType != null) {
        sampleMap['decoType'] = s.decoType;
      }
      final ceiling = decoStopCeiling(s.decoType, s.decoDepth);
      if (ceiling != null) {
        sampleMap['ceiling'] = ceiling;
      }
      if (s.decoType == 0 && s.decoTime != null) {
        sampleMap['ndl'] = s.decoTime;
      }
      return sampleMap;
    }).toList();
  }

  /// The gas switches of [parsed], addressed to positions in [tanks], the
  /// tank maps the source file itself lists for the dive.
  ///
  /// libdivecomputer reports a gas change as a new `gasMixIndex` on the
  /// samples ([breathedGasSequence]), numbered against its own gas list, while
  /// the source keeps a tank list of its own. Each gas is matched to the first
  /// listed tank carrying the same mix. A dive that switches gas gets a
  /// pressureless cylinder appended for every gas it breathed that the source
  /// never listed, starting gas included: Shearwater Cloud lists only tanks
  /// with a transmitter, so a deco bottle usually has no tank of its own, and
  /// a switch needs a cylinder to point to. Each unlisted gas gets its own,
  /// even when it shares a mix with another (a rebreather's diluent and its
  /// bailout often do). A change between two gases that land on the same tank
  /// is not a switch.
  ///
  /// [profile] is the dive's profile from [samples]. Its pressure readings are
  /// stored by position in the tank list, and one whose tank index the source
  /// never listed was dropped; an appended cylinder must not inherit it, so the
  /// returned profile leaves those readings out. The download path keeps its
  /// synthesized cylinders clear of every sample tank index for the same
  /// reason.
  ///
  /// Returns [tanks] and [profile] themselves, unchanged, when the dive never
  /// switched gas or is a gauge dive.
  static ParsedGasSwitches gasSwitches(
    pigeon.ParsedDive parsed,
    List<Map<String, dynamic>> tanks, {
    required List<Map<String, dynamic>> profile,
  }) {
    // A gauge dive logs depth and time only, so it gets neither switches nor
    // fabricated cylinders, as on the download path ([resolveGasSwitches]).
    final sequence = parsed.diveMode == 'gauge'
        ? const <BreathedGas>[]
        : breathedGasSequence(parsed);
    if (sequence.length < 2) {
      return (tanks: tanks, gasSwitches: const [], profile: profile);
    }

    final resolvedTanks = [...tanks];
    final positionOfGas = <int, int>{};
    int positionOf(int gasIndex) => positionOfGas.putIfAbsent(gasIndex, () {
      final gas = parsed.gasMixes[gasIndex];
      final listed = tanks.indexWhere(
        (t) => _sameGas(t['gasMix'] as GasMix?, gas),
      );
      if (listed >= 0) return listed;
      resolvedTanks.add(<String, dynamic>{
        'gasMix': GasMix(o2: gas.o2Percent, he: gas.hePercent),
        'role': sensorlessTankRole(parsed, gasIndex),
        'order': resolvedTanks.length,
      });
      return resolvedTanks.length - 1;
    });

    // Resolved in breathing order, so on a source with no tanks the starting
    // gas lands first, where the gas-usage timeline expects it.
    final positions = [for (final g in sequence) positionOf(g.gasIndex)];
    return (
      tanks: resolvedTanks,
      profile: resolvedTanks.length == tanks.length
          ? profile
          : _withoutPressuresFrom(profile, tanks.length),
      gasSwitches: [
        for (var i = 1; i < sequence.length; i++)
          if (positions[i] != positions[i - 1])
            <String, dynamic>{
              'timestamp': sequence[i].timeSeconds,
              'depth': sequence[i].depthMeters,
              'tankIndex': positions[i],
            },
      ],
    );
  }

  /// [profile] without the pressure readings of tank index [firstUnlisted]
  /// and above. Points that carry none of those are kept as they are.
  static List<Map<String, dynamic>> _withoutPressuresFrom(
    List<Map<String, dynamic>> profile,
    int firstUnlisted,
  ) {
    bool listed(Map<String, dynamic> reading) =>
        (reading['tankIndex'] as int? ?? 0) < firstUnlisted;
    return [
      for (final point in profile)
        if (point['allTankPressures']
            case final List<Map<String, dynamic>> readings
            when !readings.every(listed))
          {
            for (final entry in point.entries)
              if (entry.key != 'allTankPressures') entry.key: entry.value,
            if (readings.any(listed))
              'allTankPressures': [...readings.where(listed)],
          }
        else
          point,
    ];
  }

  /// Whether [listed] is the same mix as [gas]. The native bridges compute
  /// percentages as `fraction * 100.0`, so a whole-percent mix can arrive a
  /// few ULPs off; half a percentage point separates any two real mixes.
  static bool _sameGas(GasMix? listed, pigeon.GasMix gas) =>
      listed != null &&
      (listed.o2 - gas.o2Percent).abs() < 0.5 &&
      (listed.he - gas.hePercent).abs() < 0.5;

  /// The coldest sample temperature, or null when no sample carried one.
  /// Used as a water-temperature fallback when the source metadata has none.
  static double? minSampleTemperature(pigeon.ParsedDive parsed) {
    final temps = parsed.samples
        .map((s) => s.temperatureCelsius)
        .whereType<double>()
        .toList();
    if (temps.isEmpty) return null;
    return temps.reduce((a, b) => a < b ? a : b);
  }
}
